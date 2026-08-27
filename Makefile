BIN := $(shell go env GOPATH)/bin
PROTOC_GEN_GO_VERSION := v1.36.12
PROTOC_GEN_GO_GRPC_VERSION := v1.6.2

.PHONY: tools generate lint breaking test-migrations build

## install pinned codegen plugins (buf is expected on PATH)
tools:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@$(PROTOC_GEN_GO_VERSION)
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@$(PROTOC_GEN_GO_GRPC_VERSION)

## regenerate Go stubs from proto/ into gen/
generate:
	PATH="$(BIN):$$PATH" buf generate

lint:
	buf lint

breaking:
	buf breaking --against '.git#branch=main'

## apply migrations to an ephemeral Docker Postgres and assert invariants
test-migrations:
	./scripts/test-migrations.sh

build:
	go build ./...
