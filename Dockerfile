FROM debian:trixie-slim AS codex-package

ENV CODEX_VERSION=0.159.2 \
    CODEX_ARCHIVE=codex-package-x86_64-unknown-linux-musl.tar.gz \
    CODEX_SHA256=9e2d29a713b94478b240dec2f10e11324cd05fad76dc43e7c639bdf8a1337a6b \
    CODEX_RELEASE_BASE_URL=https://github.com/openai/codex/releases/download

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gzip \
      tar; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /opt/codex /tmp/codex-download; \
    curl --fail --location --silent --show-error --retry 3 \
      "${CODEX_RELEASE_BASE_URL}/rust-v${CODEX_VERSION}/${CODEX_ARCHIVE}" \
      --output "/tmp/codex-download/${CODEX_ARCHIVE}"; \
    printf '%s  %s\n' \
      "${CODEX_SHA256}" \
      "/tmp/codex-download/${CODEX_ARCHIVE}" \
      | sha256sum -c -; \
    tar --extract --gzip --no-same-owner \
      --file "/tmp/codex-download/${CODEX_ARCHIVE}" \
      --directory /opt/codex; \
    test -f /opt/codex/codex-package.json; \
    test -x /opt/codex/bin/codex; \
    test -x /opt/codex/bin/codex-code-mode-host; \
    test -x /opt/codex/codex-path/rg; \
    test -x /opt/codex/codex-resources/bwrap; \
    rm -rf /tmp/codex-download

FROM debian:trixie-slim

RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      coreutils \
      findutils \
      git \
      grep \
      passwd; \
    rm -rf /var/lib/apt/lists/*

COPY --from=codex-package --chown=0:0 /opt/codex/ /opt/codex/

RUN set -eux; \
    chmod -R go-w /opt/codex; \
    groupadd --gid 1000 codex; \
    useradd \
      --uid 1000 \
      --gid 1000 \
      --home-dir /home/codex \
      --create-home \
      --shell /bin/bash \
      codex; \
    mkdir -p /home/codex/.codex /workspace; \
    chown -R 1000:1000 /home/codex /workspace; \
    chmod 0700 /home/codex/.codex; \
    test -z "$(find /opt/codex \( ! -uid 0 -o ! -gid 0 \) -print -quit)"

ENV HOME=/home/codex
ENV PATH=/opt/codex/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /workspace
USER 1000:1000
CMD ["/bin/bash"]
