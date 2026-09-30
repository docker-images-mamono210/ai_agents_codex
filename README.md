# ai_agents_codex

This repository manages the container image for the Codex CLI.
This initial configuration covers the lint CI setup in Redmine #5462 only.
The Dockerfile, image build, and structure tests will be added in #5463.
No image is built or published at this stage.

## Project Details

| Item | Value |
| --- | --- |
| Repository | `docker-images-mamono210/ai_agents_codex` |
| Default branch | `main` |
| Parent ticket | Redmine #5461 |
| Initial CI setup | Redmine #5462 |
| Next implementation | Redmine #5463 |

## Files

```text
.circleci/config.yml
.yamllint
README.md
```

`.circleci/config.yml` defines lint jobs only.
`.yamllint` is identical to the reference configuration.
The `Dockerfile` entry in its ignore list does not require a Dockerfile to exist or an image build to run.

## CircleCI

The workflow is named `lint`. Jobs run in the following order:

```text
trailing-whitespace -> yamllint -> detect-secrets
```

| Job | Purpose |
| --- | --- |
| `trailing-whitespace` | Check for trailing whitespace using `orbss/trailing-whitespace@1.0.0` |
| `yamllint` | Install and run yamllint using `orbss/yamllint@1.1.5` and `.yamllint` |
| `detect-secrets` | Scan for potential secrets using `cimg/python:3.14` and fail if any are found |

The `detect-secrets` scan excludes `KeywordDetector`; its scan settings and pass/fail logic are retained from the reference configuration.
This check does not guarantee that all secrets are absent.

No branch-restricting `filters` are configured.
After connecting CircleCI, verify that the workflow runs on both a working branch and `main`.

### Connection and Authentication Requirements

Do not attach contexts to CI jobs.
Do not register additional credentials in CircleCI project environment variables.
Limit checkout authentication to the access required to read the target repository.
Do not add credentials for Codex, Redmine, Git push, or GHCR publishing.

The configuration does not define GHCR login, image push, or registry cache writes.
Pulling public images required by the configured CircleCI jobs is allowed.
A human must also verify that shared or organization-level settings do not inject unnecessary credentials.

## Setup

1. Use the repository `docker-images-mamono210/ai_agents_codex`.
   Confirm the repository visibility before continuing.
   If the repository already contains files or history, inspect them before making changes and do not overwrite or reinitialize them without approval.
2. Place the three files at the repository root and track them in Git.
   `.circleci` and `.yamllint` are hidden entries; make sure they are included when copying the files.
   Set the default branch to `main`.
3. Connect CircleCI to the target repository and use `.circleci/config.yml`.
   Also verify that the organization settings allow the use of both `orbss/yamllint` and `orbss/trailing-whitespace`.
   A human must decide on and apply any required administrative changes.
4. Verify that all three lint jobs pass on a working branch, then review the changes.
   Record the reference repository, commit, and scope of changes listed below in the PR description or equivalent review record.
5. Squash merge into `main` and verify that all three lint jobs pass for the same merged commit.
   Record the results in Redmine #5462 together with the operational checks listed below.

Placing the files in the repository does not complete #5462.
Actual CircleCI run results and a review of the administrative settings are required.

### Records to Add to Redmine #5462

A human must inspect the actual environment and record the following information.
Do not record secret values.

| Item | Information to record |
| --- | --- |
| Repository | URL, approved visibility, and default branch `main` |
| CircleCI | URL or identifier that identifies the target project |
| Working branch | Commit SHA and run URL showing that all three lint jobs passed |
| `main` | Post-merge commit SHA and run URL showing that all three lint jobs passed for that same commit |
| Contexts | Confirmation that no contexts are used |
| Project environment variables | Registered names and purposes; confirmation that no additional credentials are registered. Do not record values |
| Checkout authentication | Type, purpose, target repository, and permission scope. Do not record key or token values |

## Reference and Changes

The reference repository is `docker-images-mamono210/circleci-executors_yamllint`.

Reference commit: `2f40c25b6e10925609eaadeb65e05cf5126b0dd9`

- [Reference CI configuration](https://github.com/docker-images-mamono210/circleci-executors_yamllint/blob/2f40c25b6e10925609eaadeb65e05cf5126b0dd9/.circleci/config.yml)
- [Reference yamllint configuration](https://github.com/docker-images-mamono210/circleci-executors_yamllint/blob/2f40c25b6e10925609eaadeb65e05cf5126b0dd9/.yamllint)

The target configuration preserves the same lint stages and dependency order, while adapting the lint implementation for this repository:

- removes the image-build-only `docker` executor;
- removes the `docker-build-and-push` job and its workflow invocation;
- removes the `ghcr` context;
- renames the workflow from `build` to `lint`;
- uses `orbss/trailing-whitespace@1.0.0` instead of the reference repository's dedicated trailing-whitespace executor image;
- updates yamllint from `orbss/yamllint@0.0.4` to `orbss/yamllint@1.1.5` and runs `yamllint/install` before `yamllint/execute`;
- updates the detect-secrets executor from `cimg/python:3.11` to `cimg/python:3.14`.

`.yamllint` is unchanged from the reference configuration.

## Out of Scope

This change does not include a Dockerfile, image build or structure tests, or GHCR publishing.
It also does not include Codex authentication or execution, a production sandbox, Redmine connectivity, or Agent Runner changes.

Work on #5463 can begin only after #5462 is complete.
See parent ticket #5461 for the image specifications.
