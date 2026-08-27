// Package koinoniaproto holds Koinonia's shared contracts: the PostgreSQL schema
// (as migrations) and the gRPC/protobuf service definitions consumed by
// koinonia-server and koinonia-fuse.
//
// Generated protobuf Go will live under this module (see docs/adrs). For now the
// package exposes a version marker so consumers can prove the replace-directive
// wiring builds end-to-end (issue S00).
package koinoniaproto

// ContractVersion marks the shared schema + gRPC contract revision.
const ContractVersion = "v0"
