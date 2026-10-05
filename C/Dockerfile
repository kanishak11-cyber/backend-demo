FROM debian:trixie-slim AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends g++ make pkg-config libpq-dev libhiredis-dev libasio-dev ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
ARG CROW_VERSION=1.3.4
RUN curl -fsSL "https://github.com/CrowCpp/Crow/archive/refs/tags/v${CROW_VERSION}.tar.gz" | tar -xz -C /tmp \
 && cp -r "/tmp/Crow-${CROW_VERSION}/include/." /usr/local/include/
WORKDIR /src
COPY Makefile main.cpp ./
RUN make

FROM debian:trixie-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends libpq5 libhiredis1.1.0 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/server /usr/local/bin/server
EXPOSE 8081
USER nobody
CMD ["server"]
