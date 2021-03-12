FROM golang:1.16.2-alpine3.13 AS builder
RUN apk add --no-cache git openssh gcc musl-dev
RUN go get github.com/rlmcpherson/s3gof3r/gof3r

FROM philipslabs/siderite:latest AS siderite

FROM alpine:latest
RUN apk add --no-cache git openssh openssl bash postgresql-client
WORKDIR /app
COPY backup.sh backup.sh
RUN chmod +x /app/backup.sh
COPY --from=builder /go/bin/gof3r /app/gof3r
COPY --from=siderite /app/siderite /app/siderite

ENTRYPOINT ["/app/siderite","runner"]
