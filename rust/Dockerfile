FROM rust:1-slim-trixie AS build
WORKDIR /src
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release --locked

FROM debian:trixie-slim
COPY --from=build /src/target/release/rust-service /usr/local/bin/rust-service
EXPOSE 8082
USER nobody
CMD ["rust-service"]
