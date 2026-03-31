# Audos Platform — Issue Backlog

Issues and questions to raise with the Audos platform team. Close items by moving them to **Resolved** with a date and outcome.

---

## Open

| # | Raised | Area | Issue |
|---|--------|------|-------|
| 3 | 2026-03-31 | web-api | `analyze` action: `research` object not returned — response shape appears incomplete or action not fully deployed |
| 2 | 2026-03-31 | web-api | `isJsRendered` boolean field missing from `fetch` response — warning text fires correctly but the flag itself is undefined |
| 1 | 2026-03-31 | web-api | `contentLength` from `fetch` on JS-rendered SPAs returns just the title length — need metadata/analyze as workaround *(partially resolved by changelog 20260331-1119, but isJsRendered flag still broken)* |

---

## Resolved

| # | Raised | Resolved | Area | Issue | Outcome |
|---|--------|----------|------|-------|---------|
| R3 | 2026-03-31 | 2026-03-31 | analytics-api | `URLSearchParams is not defined` crash | Fixed — rewrote with manual `buildQuery()` helper |
| R2 | 2026-03-31 | 2026-03-31 | web-api | `response.headers.get is not a function` | Fixed — reads full response as text now |
| R1 | 2026-03-31 | 2026-03-31 | db-api | Insert into `dashboard_activity` failed — missing required `title` field | Documented schema, `title` is required |
