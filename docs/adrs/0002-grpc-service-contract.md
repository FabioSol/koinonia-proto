# koinonia-proto ADR-0002 — gRPC service contract

**Status:** Accepted · Implements general ADR-0003, 0004, 0006, 0011, 0012

Illustrative protobuf (field numbers/naming refined during authoring). The FUSE client maps typed errors to POSIX errno at its boundary.

```protobuf
syntax = "proto3";
package koinonia.v1;

service Koinonia {
  // --- namespace / metadata (hot path) ---
  rpc Lookup   (LookupRequest)   returns (Node);
  rpc ReadDir  (ReadDirRequest)  returns (ReadDirResponse);
  rpc Getattr  (GetattrRequest)  returns (Attr);        // mtime = base_epoch + version

  // --- blobs (bytes never proxied through here) ---
  rpc BlobExists (BlobExistsRequest) returns (BlobExistsResponse); // dedup pre-check
  rpc PresignGet (PresignRequest)    returns (PresignResponse);
  rpc PresignPut (PresignRequest)    returns (PresignResponse);

  // --- writes (OCC/CAS) ---
  rpc Commit  (CommitRequest)  returns (CommitResponse);  // Flush()/Rename() CAS
  rpc Publish (PublishRequest) returns (PublishResponse); // atomic base_version txn

  // --- real-time invalidation ---
  rpc Subscribe (SubscribeRequest) returns (stream Invalidation);
}

message Node {
  string logical_id = 1;
  string name = 2;
  string kind = 3;              // space|section|article|folder
  string draft_id = 4;
  string content_hash = 5;
  bytes  frontmatter_json = 6;
  int32  version = 7;
  bool   is_deleted = 8;
  string parent_id = 9;
}

message CommitRequest {
  string logical_id = 1;
  int32  expected_version = 2;  // handle.baseVersion (immutable, ADR-0004)
  string content_hash = 3;
  bytes  frontmatter_json = 4;  // client-parsed; server validates vs space schema
  string draft_id = 5;
  // rename-as-CAS: optional target semantics carried here
}

message CommitResponse { int32 new_version = 1; }

message PublishRequest { string draft_id = 1; }
message PublishResponse {
  bool ok = 1;
  repeated ConflictFile conflicts = 2;  // when ok=false -> 409 -> client surfaces list
}
message ConflictFile { string logical_id = 1; string path = 2;
                       int32 base_version = 3; int32 current_version = 4; }

message Invalidation {          // thin delta only (no content)
  string logical_id = 1; int32 version = 2; string draft_id = 3; string parent_id = 4;
}
```

## Error contract (typed status → FUSE errno)

| Backend condition | gRPC status / detail | FUSE errno |
|---|---|---|
| Version mismatch (CAS 0 rows) | `FAILED_PRECONDITION` / 409 | `ESTALE` |
| Frontmatter schema invalid | `INVALID_ARGUMENT` / 422 | `EINVAL` (+ `.koinonia_errors.log`) |
| RBAC / branch protection | `PERMISSION_DENIED` / 403 | `EACCES` |
| Write under `.history/` | `FAILED_PRECONDITION` (read-only) | `EROFS` |
| Resolved node tombstoned | `NOT_FOUND` | `ENOENT` |
| Co-edit advisory lock held | `UNAVAILABLE` (locked) | `EAGAIN` |

## Consequences

- One connection carries hot-path RPCs + the invalidation stream (general ADR-0012).
- The errno mapping is the AI-recovery UX and must be identical in the FUSE client.
