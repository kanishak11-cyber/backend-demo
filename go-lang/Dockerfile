FROM golang:1.27 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/go-service .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/go-service /go-service
EXPOSE 8080
ENTRYPOINT ["/go-service"]
