FROM golang:1.22-alpine AS builder

# working directory (/build).
WORKDIR /build

# dependency using go mod.
COPY go.mod go.sum ./
RUN go mod download

# Copy the code
COPY . .

# environment variables for docker image
# and build the server.
ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64
RUN apk add --no-cache dumb-init
RUN go build -ldflags="-s -w" -o apiserver ./main.go

FROM alpine:latest

# working directory (/build).
WORKDIR /

# Copy the Pre-built binary file from the previous stage.
COPY --from=builder ["/usr/bin/dumb-init", "/usr/bin/dumb-init"]
COPY --from=builder ["/build/apiserver", "/"]
COPY --from=builder ["/build/config.json", "/config.json"]

# Export necessary port.
EXPOSE 3000

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/apiserver"]

