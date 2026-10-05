# The load generator, pinned to the same oha version used for native runs.
FROM debian:trixie-slim
ARG OHA_VERSION=1.16.0
ARG TARGETARCH
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && curl -fsSL -o /usr/local/bin/oha "https://github.com/hatoo/oha/releases/download/v${OHA_VERSION}/oha-linux-${TARGETARCH}" \
 && chmod +x /usr/local/bin/oha \
 && apt-get purge -y curl && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["oha"]
