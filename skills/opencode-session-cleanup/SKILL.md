---
name: opencode-session-cleanup
description: List, filter, and delete old OpenCode sessions and reclaim the disk space they hold in the OpenCode data directory (opencode.db), then sweep orphaned tool-output, session_diff, and log leftovers. Use when asked to clean up or prune OpenCode session history, delete sessions older than a date, or shrink the OpenCode data directory.
---

# OpenCode Session Cleanup

Delete old OpenCode sessions safely and reclaim space, using only the official
CLI. Everything lives in one SQLite database; deleting a session also removes
its event stream and cascades its messages and parts.

## Principles

- **Ask before acting.** Never delete until the cutoff, filters, and the exact
  session list are confirmed with the user.
- **CLI deletes only.** Use `opencode session delete <id>`. Do NOT `DELETE FROM`
  sessions by hand - the CLI also removes the session's `event_sequence` +
  `event` rows and cascades `message` -> `part`, `todo`, `session_share`. Raw SQL
  leaves orphaned data behind.
- **Read-only recon first.** Enumerate and size the candidates before touching
  anything.
- **Never delete the current session** (or an ancestor of it).
- **Snapshots are shared.** `snapshot/<projectId>/` is per-project and reused by
  newer sessions - never delete it manually.
- **Verify, then reclaim.** Confirm rows are gone before VACUUM.
- **Sweep orphans last.** Only touch `tool-output/` after session deletion, so
  nothing a surviving session still references is removed.
- **Derive paths, never hardcode them.** Resolve the data directory at runtime
  (see below) so the skill works on any Linux machine.

## Paths (portable - do this first)

The OpenCode data directory is not guaranteed to be `~/.local/share/opencode`;
it follows `XDG_DATA_HOME` and can be overridden. Resolve it once at the start
of the session and use these variables everywhere:

```sh
OC_DATA="$(opencode debug paths | awk '$1=="data"{print $2}')"  # data dir
OC_DB="$(opencode db path)"                                      # = $OC_DATA/opencode.db
OC_LOG="$OC_DATA/log/opencode.log"
```

If `opencode debug paths` is unavailable on an older build, fall back to:

```sh
OC_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
OC_DB="$OC_DATA/opencode.db"
```

This skill lives at `~/dotfiles/skills/opencode-session-cleanup/` (the dotfiles
repo is always at `~/dotfiles`). Reference any skill-internal resources by
**relative** path (e.g. `scripts/`), never by an absolute `/home/<user>/...`
path.

## Where the data lives

| Path | What |
|------|------|
| `$OC_DB` | sessions/messages/parts/events (WAL mode) |
| `$OC_DB-wal`, `$OC_DB-shm` | write-ahead log + shared memory |
| `$OC_DATA/snapshot/<projectId>/` | per-project git snapshots (shared) |
| `$OC_DATA/storage/session_diff/<sessionID>.json` | per-session diff cache |
| `$OC_DATA/tool-output/tool_<id>` | large tool outputs, referenced from `part.data` |
| `$OC_LOG` | single append-only runtime log |

Space is dominated by `event`, then `part`, then `message`. Deleting a session
reclaims its event rows (the largest share) plus its messages and parts.

## Step 0 - Ask the user (use the question tool)

Collect these before any query:

1. **Cutoff** - "older than" what duration/date. Compute seconds with
   `date -d '1 month ago' +%s`, then append `000` for epoch milliseconds.
2. **Basis** - age by last activity (`time_updated`, default) or creation
   (`time_created`)? State which you used.
3. **Project filter** - all projects, or the current project / global only.
4. **Protections** - exclude archived? shared? title patterns? an explicit
   keep-list of IDs?
5. **Backup** - none, SQLite `.backup`, and/or per-session `opencode export`.
6. **Reclaim timing** - VACUUM now, or delete only?
7. **Hygiene scope** - also sweep orphaned `tool-output/`, `session_diff/`,
   and the log (see section H)?

If the user has no preference, state your default and proceed; never guess
silently. A 1-month cutoff is a good default.

If recon finds no candidates (e.g. the user already cleaned recently), report
that plainly and stop - it is normal, not an error.

## Step 1 - Recon (read-only)

List projects, then the candidate set. `opencode session list` only shows the
current project + global, so use `opencode db` to see every session.

```sh
opencode db "SELECT id, worktree FROM project"
CUT=$(date -d '1 month ago' +%s)000
opencode db "SELECT id, datetime(time_created/1000,'unixepoch','localtime') AS created,
                    datetime(time_updated/1000,'unixepoch','localtime') AS updated,
                    project_id, time_archived, share_url, parent_id, substr(title,1,50) AS title
             FROM session WHERE time_updated < $CUT ORDER BY time_created" --format json
```

Safety checks. A candidate that is a parent of a **newer** session is unsafe:
deleting it recursively deletes the child.

```sh
# candidates that are parents (their children will also be removed)
opencode db "SELECT p.id, count(c.id) FROM session p JOIN session c ON c.parent_id=p.id
             WHERE p.time_updated < $CUT GROUP BY p.id"
# candidates with a NEWER child -> do not delete without asking
opencode db "SELECT c.id, c.title FROM session c
             WHERE c.parent_id IN (SELECT id FROM session WHERE time_updated < $CUT)
               AND c.time_updated >= $CUT"
```

If a candidate parent has a child that is also a candidate, the child will be
removed recursively when the parent is deleted - expect the later explicit
delete of that child to report `Session not found` (see Step 4).

Size the reclaimable content:

```sh
opencode db "SELECT
  (SELECT sum(length(data)) FROM event   WHERE aggregate_id IN (SELECT id FROM session WHERE time_updated < $CUT)) AS event_bytes,
  (SELECT sum(length(data)) FROM message WHERE session_id   IN (SELECT id FROM session WHERE time_updated < $CUT)) AS message_bytes,
  (SELECT sum(length(data)) FROM part    WHERE session_id   IN (SELECT id FROM session WHERE time_updated < $CUT)) AS part_bytes"
```

Also record the baseline footprint:

```sh
du -sh "$OC_DATA"
opencode db "SELECT (SELECT count(*) FROM session) AS sessions, (SELECT count(*) FROM event) AS events"
```

## Step 2 - Confirm

Show a table (ID, last active, project, title, protected?) plus the estimated
reclaimable space, and require explicit confirmation before deleting anything.

## Step 3 - Backup (only if requested)

Consistent DB copy (requires the `sqlite3` binary; if missing, fall back to
per-session `opencode export`):

```sh
BACKUP="$HOME/opencode-backup-$(date +%F)"
mkdir -p "$BACKUP"
sqlite3 "$OC_DB" ".backup '$BACKUP/opencode.db'"
```

Re-importable JSON per session:

```sh
opencode export <id> > "$BACKUP/<id>.json"
```

## Step 4 - Delete

Delete one session per ID via the CLI. Put the confirmed IDs in an **array** and
iterate exactly.

```sh
IDS=(ses_aaaaaaaaaaaa ses_bbbbbbbbbbbb)   # the confirmed list
for id in "${IDS[@]}"; do
  echo "deleting $id"
  opencode session delete "$id" || echo "FAILED $id"
done
```

zsh note: OpenCode's shell is zsh, where `for id in $IDS` does **not** word-split
a variable and silently passes the whole list as one ID. Always use an array
`"${IDS[@]}"` (or `${=IDS}`) for a list held in a variable.

A `Session not found` result is expected for a child that was already removed
recursively with its parent (Step 1) - treat it as success and continue.

Never target the current session (or an ancestor of it). `$OPENCODE_SESSION_ID`
is frequently **unset** in practice, so do not rely on it: use the conversation's
own session ID, and re-check the candidate list just before deleting to assert
the current session is absent.

## Step 5 - Verify

```sh
opencode db "SELECT count(*) AS sessions FROM session"
opencode db "SELECT count(*) AS events FROM event"
opencode db "SELECT count(*) AS parts FROM part"
# leftover rows for the deleted IDs must be 0 (event, event_sequence, message, part):
IDS_SQL="$(printf "'%s'," "${IDS[@]}")"; IDS_SQL="${IDS_SQL%,}"
opencode db "SELECT count(*) FROM event WHERE aggregate_id IN ($IDS_SQL)"
opencode db "SELECT count(*) FROM event_sequence WHERE aggregate_id IN ($IDS_SQL)"
opencode db "SELECT count(*) FROM message WHERE session_id IN ($IDS_SQL)"
opencode db "SELECT count(*) FROM part WHERE session_id IN ($IDS_SQL)"
opencode db "PRAGMA integrity_check"
```

## Step 6 - Reclaim (only if requested)

VACUUM needs ~1x the DB size free temporarily; check `df -h` first and warn if
tight. Run with other OpenCode instances closed where possible.

```sh
opencode db "PRAGMA wal_checkpoint(TRUNCATE)"
opencode db "VACUUM"
opencode db "PRAGMA wal_checkpoint(TRUNCATE)"   # VACUUM can leave a large WAL
du -sh "$OC_DATA"
```

VACUUM works even while the current session holds the DB. `wal_checkpoint` may
print `busy 0` (fields: `busy log checkpointed`) - that is fine, the WAL is
already drained. Report before/after DB and directory sizes.

## H. Data hygiene (optional; run AFTER session cleanup)

Sweep leftovers that reference sessions which no longer exist. Check first,
delete second, and report reclaimed bytes per area. Use `find` rather than a bare
glob: an unmatched glob aborts a zsh script with `no matches found`.

### tool-output orphans

Tool-output filenames are referenced from `part.data` as an absolute path
(`$OC_DATA/tool-output/tool_<id>`). A file is orphaned when no surviving part
mentions its basename.

```sh
find "$OC_DATA/tool-output" -maxdepth 1 -type f -name 'tool_*' | while read -r f; do
  id=$(basename "$f")
  n=$(opencode db "SELECT count(*) FROM part WHERE data LIKE '%$id%'" 2>/dev/null | tail -1)
  printf '%s refs=%s\n' "$id" "$n"
done
```

Delete only entries whose `refs` is `0`. Never delete a referenced file - it
backs a live session's tool output.

### session_diff orphans

```sh
find "$OC_DATA/storage/session_diff" -maxdepth 1 -type f -name '*.json' | while read -r f; do
  b=$(basename "$f" .json)
  n=$(opencode db "SELECT count(*) FROM session WHERE id='$b'" 2>/dev/null | tail -1)
  printf '%s session_exists=%s\n' "$b" "$n"
done
```

Delete files whose session no longer exists.

### Log

`$OC_LOG` is a single append-only file with no rotation. It is live while OpenCode
runs; only remove or truncate it when OpenCode is stopped, and confirm with the
user first. It will be recreated.

### Snapshots

`$OC_DATA/snapshot/<projectId>/` is per-project and shared across that project's
sessions. Leave it alone. Only offer to remove a project's snapshot directory
when that project has **zero** remaining sessions, and only with explicit
confirmation. Map directories via `SELECT id, worktree FROM project`.

## Notes

- `opencode session delete` removes children recursively - vet parents in
  Step 1 before deleting.
- Leave `snapshot/` alone (per-project, shared with newer sessions).
- Restart opencode after creating or editing this skill so it is reloaded.
