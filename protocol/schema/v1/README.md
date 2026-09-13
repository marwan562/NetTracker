# NetTracker IPC protocol v1

Transport: Unix domain socket at
`~/Library/Application Support/NetTracker/agent.sock`.
Framing: newline-delimited JSON, one request per line, one response per line.

## Requests

```json
{ "version": 1, "type": "snapshot" }
{ "version": 1, "type": "history", "days": 7 }
{ "version": 1, "type": "reset" }
{ "version": 1, "type": "network_changed" }
{ "version": 1, "type": "sleep" }
{ "version": 1, "type": "wake" }
```

## Snapshot response

```json
{
  "version": 1,
  "type": "snapshot",
  "session": { "upload_bytes": 1827364, "download_bytes": 82173642 },
  "today": { "upload_bytes": 91827364, "download_bytes": 812736482 },
  "upload_rate": 48000,
  "download_rate": 1240000
}
```

All byte values are exact integer bytes. Presentation formatting
(KB/MB/GB) happens only in the Swift UI layer.

## Versioning

Unknown `type` values return `{ "type": "error", "error": ... }`.
Mismatched `version` values return an error response; future versions
must be introduced alongside v1, never by changing v1 field semantics.
