# ai_agents_codex

This repository builds and verifies a container image for the Codex CLI.
The image work in this revision implements Redmine #5463 under parent #5461.
GHCR publication, Codex authentication, Redmine connectivity, remote Git push,
and production Agent Runner isolation are outside this change.

## Image Contract

| Item | Value |
| --- | --- |
| Repository | `docker-images-mamono210/ai_agents_codex` |
| Target platform | `linux/amd64` |
| Base image | `debian:trixie-slim` |
| Codex | `0.159.2` |
| Codex release asset | `codex-package-x86_64-unknown-linux-musl.tar.gz` |
| Package root | `/opt/codex` |
| Default user | `codex`, UID/GID `1000:1000` |
| HOME | `/home/codex` |
| Default CODEX_HOME | `/home/codex/.codex` |
| Work directory | `/workspace` |
| Default command | `/bin/bash` |
| ENTRYPOINT | none |
| Structure test | `container-structure-test 1.22.1` |

The official Codex package layout is preserved under `/opt/codex`.
`/opt/codex` and every entry below it are owned by `root:root`, and the default
user must not be able to add, remove, replace, or modify files there.

The product image does not contain sudo and does not grant sudo privileges.
It also does not contain credentials for Codex, Redmine, Git push, or GHCR.

## Files

```text
.circleci/config.yml
.dockerignore
Dockerfile
README.md
container-structure-test.yaml
```

`.dockerignore` excludes the entire local build context. The Dockerfile does not
COPY local repository files, so no allowlist exceptions are required.

## Codex Package Integrity

The Codex release asset is pinned to this SHA-256:

```text
9e2d29a713b94478b240dec2f10e11324cd05fad76dc43e7c639bdf8a1337a6b  codex-package-x86_64-unknown-linux-musl.tar.gz
```

The Dockerfile verifies that value before extracting the package. Extraction
uses `tar --no-same-owner`; the final image also copies the package as
`root:root` and removes group/other write permission.

The CI host installs `container-structure-test 1.22.1` only after verifying:

```text
fa35e89512a8978585f76cf41397956d2e3a30c62c2ad3fb857b1597074d14ca  container-structure-test-linux-amd64
```

A checksum mismatch must stop the build or CI before the downloaded artifact is
used. Do not replace the expected checksum with a value calculated from the same
untrusted download in the normal build path.

## Build and Verification

The following commands are the same commands and options used by CircleCI.
Values that differ per run, such as `IMAGE_ID`, `SOURCE_COMMIT`, and `FIXTURE`,
are variables only; the verification behavior is the same.

### 1. Build the image

```bash
set -euo pipefail
test "$(uname -m)" = "x86_64"
docker build --platform linux/amd64 --tag codex:test .
IMAGE_ID="$(docker image inspect codex:test --format '{{.Id}}')"
SOURCE_COMMIT="${CIRCLE_SHA1:-$(git rev-parse HEAD)}"
echo "source_commit=${SOURCE_COMMIT}"
echo "image_id=${IMAGE_ID}"
```

### 2. Verify image metadata

```bash
set -euo pipefail
PLATFORM="$(docker image inspect "$IMAGE_ID" --format '{{.Os}}/{{.Architecture}}')"
ENTRYPOINT="$(docker image inspect "$IMAGE_ID" --format '{{json .Config.Entrypoint}}')"
CMD="$(docker image inspect "$IMAGE_ID" --format '{{json .Config.Cmd}}')"
USER_VALUE="$(docker image inspect "$IMAGE_ID" --format '{{.Config.User}}')"
WORKDIR="$(docker image inspect "$IMAGE_ID" --format '{{.Config.WorkingDir}}')"
test "$PLATFORM" = "linux/amd64"
test "$ENTRYPOINT" = "null"
test "$CMD" = '["/bin/bash"]'
test "$USER_VALUE" = "1000:1000"
test "$WORKDIR" = "/workspace"
echo "platform=${PLATFORM}"
echo "entrypoint=${ENTRYPOINT}"
echo "cmd=${CMD}"
echo "user=${USER_VALUE}"
echo "workdir=${WORKDIR}"
```

### 3. Install container-structure-test

```bash
set -euo pipefail
CST_VERSION="1.22.1"
CST_SHA256="fa35e89512a8978585f76cf41397956d2e3a30c62c2ad3fb857b1597074d14ca"  # pragma: allowlist secret
CST_BIN="/tmp/container-structure-test"
curl --fail --location --silent --show-error --retry 3 \
  "https://github.com/GoogleContainerTools/container-structure-test/releases/download/v${CST_VERSION}/container-structure-test-linux-amd64" \
  --output "$CST_BIN"
printf '%s  %s\n' "$CST_SHA256" "$CST_BIN" | sha256sum -c -
chmod +x "$CST_BIN"
```

### 4. Run structure tests

```bash
set -euo pipefail
"$CST_BIN" test \
  --image "$IMAGE_ID" \
  --config container-structure-test.yaml \
  --platform linux/amd64
```

The structure test checks the package layout, Codex version, Code Mode host,
packaged ripgrep and bwrap, default user, HOME, work directory, command,
ENTRYPOINT, package ownership, package write protection, sudo absence,
`safe.directory` absence, writable user areas, and absence of personal SSH and
Codex credential files.

`codex --version` must return `codex-cli 0.159.2` with exit code 0 and its
standard error must not contain `could not create PATH aliases`.

### 5. Run the offline bind-mount verification

```bash
set -euo pipefail
FIXTURE="$(mktemp -d)"
trap 'sudo rm -rf "$FIXTURE"' EXIT
git -C "$FIXTURE" init --quiet
sudo chown -R 1000:1000 "$FIXTURE"
docker run --rm \
  --network none \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --volume "$FIXTURE:/workspace:rw" \
  "$IMAGE_ID" \
  /bin/bash -c '
    set -euo pipefail
    test "$(stat -c "%u:%g" /workspace)" = "1000:1000"
    test "$(stat -c "%u:%g" /workspace/.git)" = "1000:1000"
    test -z "$(git -C /workspace status --porcelain)"
    test -z "$(git config --show-origin --get-all safe.directory || true)"
    test_file="/workspace/.codex-write-test"
    printf "ok" > "$test_file"
    test "$(cat "$test_file")" = "ok"
    rm "$test_file"
    version_output="$(codex --version 2>/tmp/codex-version.err)"
    test "$version_output" = "codex-cli 0.159.2"
    ! grep -F "could not create PATH aliases" /tmp/codex-version.err
    /opt/codex/bin/codex-code-mode-host --help > /tmp/code-mode-help
    grep -F -- "--listen" /tmp/code-mode-help
    /opt/codex/codex-path/rg --version | grep -E "^ripgrep [0-9]+\\."
  '
echo "offline_bind_mount_verification=PASS"
```

The fixture is intentionally created on the Docker host, including its `.git`
directory, and then made `1000:1000` before mounting. Do not use
`safe.directory` to bypass an ownership mismatch.

## Source Mount Requirements

The Agent runtime must prepare a disposable clone outside the container and bind
mount only that clone to `/workspace` as read/write. The clone root, `.git`, and
all files and directories below it must be owned by `1000:1000` as observed by
the container.

Do not mount the host HOME, SSH agent, Docker socket, Redmine credentials, Git
push credentials, or GHCR credentials into this image.

## CODEX_HOME Requirement

`CODEX_HOME` defaults to `~/.codex`, which is `/home/codex/.codex` in this
image. It must be writable by the runtime user and must not be located under the
system temporary directory, normally `/tmp`.

Codex can create helper-command aliases below `CODEX_HOME/tmp/arg0/` even for
commands such as `codex --version` or `codex --help`. If CODEX_HOME is not
writable or is under the system temporary directory, Codex can continue after
printing `could not create PATH aliases`; this image treats that warning as a
test failure.

If a future runtime makes HOME read-only, it must provide another writable
CODEX_HOME outside the system temporary directory and create that directory
before starting Codex.

## Sandbox Boundary

The production Agent runtime is not implemented by this repository change.
When the later Agent runtime has independently established its outer container
isolation policy, it may explicitly invoke Codex with
`--dangerously-bypass-approvals-and-sandbox` so Codex does not try to provide a
second sandbox boundary.

That flag is not embedded in the image, CMD, or configuration, and this image
does not automatically fall back to it. Building this image does not mean the
production sandbox is complete.

The tests in #5463 do not authenticate Codex, call a model, or prove a real Code
Mode task. They validate local CLI/package behavior only.

## CircleCI

The workflow order is:

```text
trailing-whitespace -> yamllint -> detect-secrets -> docker-build-and-test
```

`docker-build-and-test` uses the `linux/amd64` CircleCI machine executor image
`ubuntu-2604:2026.05.1` with `medium`. Docker layer caching is not enabled.
The job does not use a CircleCI context, registry login, image push, or registry
cache write.

The same locally built `IMAGE_ID` is used for image inspection,
container-structure-test, and offline `docker run` verification. The job does
not pull or rebuild the target image for testing.

## Manual Negative Controls for #5463

Before squash merge, run the following three controls on temporary commits or a
temporary branch. Do not merge the intentionally incorrect values.

| Control | Temporary change | Required failure |
| --- | --- | --- |
| Codex checksum | Replace `CODEX_SHA256` in `Dockerfile` with an incorrect SHA-256 | `docker build` must fail at `sha256sum -c` before the Codex archive is extracted |
| Structure-test checksum | Replace `CST_SHA256` in `.circleci/config.yml` with an incorrect SHA-256 | `docker-build-and-test` must fail at `sha256sum -c` before the downloaded structure-test binary is executed |
| Codex expected version | Replace `codex-cli 0.159.2` in `container-structure-test.yaml` with a deliberately incorrect expected version | `container-structure-test` must fail the Codex version command test |

For each control, record the temporary commit SHA, CircleCI workflow or job URL,
the failing step and its expected failure message, and the restored passing
branch SHA. Secret values are not part of this evidence.

After each control, restore the production values shown in this README and
rerun the full workflow. The branch used for the final PR must contain only the
correct checksums and version expectation.

Do not keep intentionally bad images, permanent failing fixtures, or a
long-lived negative-test switch in the repository. After squash merge, verify
the complete workflow again on the resulting `main` commit before closing
Redmine #5463.

## Updating Pinned Artifacts

### Codex

For a manual Codex update PR:

1. Select the exact official `openai/codex` release and the
   `codex-package-x86_64-unknown-linux-musl.tar.gz` asset.
2. Read the SHA-256 displayed for that exact asset on the GitHub release.
3. Download the asset independently and calculate `sha256sum` locally.
4. Continue only if the published value and local calculation match.
5. Update the Codex version, asset name if required, SHA-256, README, and test
   expectations in the same PR.
6. Inspect the package layout for changes to `codex-package.json`, `bin/`,
   `codex-resources/`, and `codex-path/` before merging.

### container-structure-test

For a manual structure-test update PR:

1. Select the official `GoogleContainerTools/container-structure-test` release.
2. Read the `container-structure-test-linux-amd64` value from that release's
   `checksums.txt`.
3. Download the binary independently and calculate `sha256sum` locally.
4. Continue only if the published value and local calculation match.
5. Update the version, SHA-256, README, and CI expectation in the same PR.

Do not automatically rewrite expected hashes during a normal build or CI run.

## Deferred Runtime Decisions

Codex self-update behavior and `check_for_update_on_startup` are runtime policy
questions for the later Agent execution work. This image does not configure or
invoke self-update behavior as part of #5463.

## Out of Scope

This change does not publish to GHCR, create release tags, configure Codex
authentication, run model-backed Codex work, connect to Redmine, allow remote
Git push, modify Agent Runner, or define the final production network and
filesystem isolation policy.


### container-structure-test environment handling

`container-structure-test` 1.22.1 does not reliably preserve the image environment for Docker-driver command tests. Its command-test implementation does, however, substitute `$HOME` and `$PATH` in the command arguments from the image metadata before starting the test container.

The affected tests therefore use this form:

```yaml
command: /usr/bin/env
args:
  - "HOME=$HOME"
  - "PATH=$PATH"
  - /opt/codex/bin/codex
  - --version
```

The values are not independent test-side defaults: `$HOME` and `$PATH` are resolved from the image configuration by `container-structure-test`. The metadata test independently requires `HOME=/home/codex` and the expected Codex-first `PATH`, so changing the image metadata causes the test suite to fail rather than being hidden by a separate hard-coded environment.

`CODEX_HOME` is not supplied by the tests. Codex therefore uses its default under the image `HOME`. Shell-based command tests use `bash -c`, not a login shell, so `/etc/profile` cannot replace the image-derived `PATH`.

