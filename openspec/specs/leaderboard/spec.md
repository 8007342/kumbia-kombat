# Global arcade Top 10

## Purpose

Rank eligible completed runs durably and provide three-letter arcade entry.

## Requirements

### Requirement: Rank completed runs consistently

A Cloudflare Worker SHALL route /api requests to one SQLite-backed Durable
Object per ruleset season and otherwise serve Flutter static assets. The
object SHALL serialize accepted submissions and durably store the best ten
results ordered by elapsed milliseconds ascending, Pizazz descending, then
server finish timestamp ascending. Exactly equal results retain earlier rank.
Three uppercase ASCII letters A–Z are the display identity; names are not
unique. Persist only the small leaderboard plus expiring active-run records.

#### Scenario: Concurrent finishes

WHEN two eligible finishes arrive together,
THEN both are validated against the same durable ranking state, the ordered
top ten remains deterministic, and replayed submission IDs do not duplicate.

### Requirement: Arcade entry follows the final fight

Three large letter slots SHALL be edited with up/down or swipe, tap to
advance, back to correct, and a clear submit action; support keyboard arrows
and Enter too. Default AAA, no mobile keyboard required. Entry appears only
after qualification lookup and victory; qualification is provisional until
atomic submission. Display elapsed time and Pizazz as separate columns.

#### Scenario: Rank changes while choosing initials

WHEN another player displaces a provisional qualifying result,
THEN submission completes gracefully and shows the current board and local
result, without falsely promising a global position.

### Requirement: Cheap server verification sets honest limits

POST /api/runs SHALL issue an unpredictable run ID and secret token and
record a server start time and rules/chart versions. POST
/api/runs/:id/checkpoint SHALL accept monotonic level completion milestones.
POST /api/runs/:id/finish SHALL validate all five milestones and commit a
server finish time; retries return the original finish. POST
/api/runs/:id/initials SHALL atomically consume the completed run and insert
its result if still eligible. GET /api/top SHALL return at most ten public
rows and rules version, never run secrets. Responses SHALL disable sensitive
caching; use same-origin requests, bounded JSON bodies, parameterized SQL,
per-run expiry and rate limits. Do not store IPs permanently.

Validation SHALL reject unknown/expired tokens, out-of-order milestones,
implausibly short level intervals, impossible style totals, unsupported
versions, malformed initials, duplicate completion and oversized payloads.
The server SHALL compute elapsed time rather than trust client duration.
This is lightweight tamper resistance, not proof of human play: modified
clients can fabricate plausible inputs. Strict replay verification is a
future enhancement; do not market this table as cheat-proof.

#### Scenario: Network failure

WHEN submission fails,
THEN the final local result and idempotent retry state persist, the ending
still plays, and retry never creates multiple records. Offline runs cannot
retroactively invent a server start time.

## References and implementation status

This is a design; backend and arcade UI remain to be implemented.
Use Cloudflare's SQLite Durable Object storage and migrations:
https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/

User reference for arcade entry: https://github.com/8007342/lakanoa/ .
Its contents were not retrievable in this session; reproduce the requested
three-letter interaction from the user's description, without claiming code
or assets were inspected or copied. Verify the reference before UI polish.
