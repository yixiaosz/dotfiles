---
name: system-health-check-mac
description: Run a read-only system health check on macOS (Apple Silicon or Intel, laptop or desktop), scan the unified log for error/fault spam, inspect services, storage, memory, power, network, and security posture, then write a dated maintenance report. Use when asked to check Mac system status, review logs, diagnose log spam or recurring warnings, or perform routine macOS maintenance.
---

# System Health Check (macOS)

A repeatable, **read-only** health check for macOS. It detects what the current
host actually supports, runs only the relevant checks, ranks findings by
severity, and optionally writes a dated entry to the maintenance log.

## Principles

- **Read-only by default.** Never remediate, install, purge, or edit anything
  unless the user explicitly asks. Diagnose, then propose.
- **Capability-gated.** Laptop and desktop share one skill; detect hardware and
  tools first and skip what is absent.
- **Be defensive.** Any command may be missing or require privileges. Guard with
  `command -v`, handle failures, and record what was skipped and why.
- **Always use `/usr/bin/log`.** `log` is a zsh builtin on this platform; the
  bare name fails or resolves incorrectly. Invoke `/usr/bin/log` explicitly.
- **Bound every log query.** `log show` is not `journalctl`. An unbounded or
  multi-day query can take minutes and time out. Default window is **1 hour**,
  always pass `--last` and a `--predicate`, and use `--style ndjson` for parsing.
- **Stable parsing.** Prefix data-parsing commands with `LC_ALL=C`.
- **One privileged attempt.** Try `sudo -n` once; this environment has no TTY, so
  an interactive password prompt cannot be answered. If it fails, skip the
  privileged checks and print the exact commands for the user to run manually.
- **Report noise separately.** High-volume log chatter with no functional impact
  is "log noise", not a fault. Do not present it as a problem.
- **System updates are out of scope.** This skill does not check OS or package
  updates. Say so under FINDINGS; do not run `softwareupdate`/`brew outdated`.

## Step 0 - Preflight (capability detection)

Gather context and decide which bundles apply:

```sh
date; hostname; sw_vers; uname -m; uname -r; uptime; id -u
sudo -n true 2>/dev/null && echo "sudo:ok" || echo "sudo:no"
sysctl -n hw.model hw.memsize kern.boottime
```

Detect form factor and tools:

```sh
pmset -g batt 2>/dev/null
for c in jq python3 brew system_profiler pmset powermetrics diskutil vm_stat \
         memory_pressure top ps netstat lsof scutil ifconfig networksetup \
         launchctl mdutil spctl csrutil tmutil fdesetup systemextensionsctl \
         pkgutil socketfilterfw; do
  printf '%-20s ' "$c"; command -v "$c" 2>/dev/null || echo -
done
```

Detect storage layout:

```sh
diskutil list 2>/dev/null
```

Record the capability matrix. Any check whose tools are missing is reported as
"skipped (tool absent)" rather than failing the run.

## Core checks

### A. Logs (unified log)

Use a window variable so every query shares the same span:

```sh
WINDOW="${WINDOW:-1h}"
```

Priority counts over the window:

```sh
for t in error fault; do
  printf '%s: ' "$t"
  /usr/bin/log show --last "$WINDOW" --style compact \
    --predicate "messageType == $t" 2>/dev/null | wc -l
done
```

Top spam sources, grouped by process (fall back to subsystem/image):

```sh
/usr/bin/log show --last "$WINDOW" --style ndjson \
  --predicate 'messageType == error' 2>/dev/null |
  jq -r '(.process // .subsystem // .senderImagePath // "unknown")' |
  sort | uniq -c | sort -rn | head -25
```

Faults are rarer and more actionable than errors; inspect them directly:

```sh
/usr/bin/log show --last "$WINDOW" --style compact \
  --predicate 'messageType == fault' 2>/dev/null | tail -40
```

Kernel / hardware / I/O failures:

```sh
/usr/bin/log show --last "$WINDOW" --style compact \
  --predicate 'process == "kernel"' 2>/dev/null |
  grep -aEi 'I/O error|panic|watchdog|SMC|thermal|throttle|disk|NVMe'
netstat -s 2>/dev/null | grep -Eai 'bad|drop|error'
```

Memory kills (Jetsam) and kernel panics live in diagnostic reports:

```sh
find /Library/Logs/DiagnosticReports -maxdepth 1 -name '*.ips' \
  -newermt '-4 days' -print 2>/dev/null | head -20
grep -lEi 'JetsamEvent|panic' /Library/Logs/DiagnosticReports/*.ips 2>/dev/null |
  head -10
```

Auth activity (see also bundle G):

```sh
/usr/bin/log show --last "$WINDOW" --style compact \
  --predicate 'process == "authd" OR process == "sshd" OR process == "sudo"' \
  2>/dev/null | grep -aEi 'fail|invalid|denied|authentication'
last -n 10 2>/dev/null
who 2>/dev/null
```

Readable plain log files for context:

```sh
for f in /var/log/system.log /var/log/install.log; do
  [ -r "$f" ] && echo "$f: readable" || echo "$f: not readable"
done
```

**Benign filtering:** if `~/.config/system-health-check-mac/benign.txt` exists,
read it (one regex per line, `#` comments allowed) and exclude matching messages
from the spam ranking; report the suppressed count separately. Known benign
classes on macOS: `authd ... invalidated because the client process`, DCP /
`rtbuddy` kernel chatter, `mediaanalysisd`/Photos re-analysis errors, AirDrop
sleep assertions.

### B. Services and boot

```sh
launchctl list 2>/dev/null | awk 'NR>1 && $1=="-" && $2!="0" {print $1, $2, $3}'
systemextensionsctl list 2>/dev/null
ls /Library/LaunchDaemons /Library/LaunchAgents ~/Library/LaunchAgents 2>/dev/null
pmset -g stats 2>/dev/null
pmset -g assertions 2>/dev/null
```

Notes:
- `launchctl list` columns are `PID Status Label`. `PID == "-"` means not running;
  a non-zero `Status` is the last exit code. `-9` is SIGKILL and is common for
  on-demand system agents - treat as INFO unless a third-party label is involved.
- System extensions stuck in `terminated waiting to uninstall on reboot` are WARN.
- Do **not** enumerate login items with `osascript`; the Automation/TCC prompt
  hangs in a non-interactive session. Inventory LaunchAgents/LaunchDaemons instead.

### C. Storage

```sh
df -hP 2>/dev/null
diskutil apfs list 2>/dev/null
diskutil info disk0 2>/dev/null |
  grep -Ei 'device / media name|smart|solid state|capacity|file system'
system_profiler SPStorageDataType 2>/dev/null |
  grep -Ei 'media name|medium type|protocol|smart|capacity|free'
tmutil listlocalsnapshots / 2>/dev/null
mdutil -s / 2>/dev/null
```

Notes:
- `diskutil info <disk>` reports `SMART Status: Verified` without root. Map the
  boot disk first (`diskutil info /`), then check its physical store; `disk0` is
  the common case on Apple Silicon.
- APFS inode counts are not meaningful; skip `df -i`.
- Local snapshots consume purgeable space; high counts are INFO unless disk is low.

### D. Memory and CPU

```sh
vm_stat 2>/dev/null
memory_pressure 2>/dev/null | tail -5
sysctl vm.swapusage 2>/dev/null
ps -Ao pcpu,pmem,pid,comm -r 2>/dev/null | head -12
sysctl -n vm.loadavg 2>/dev/null
top -l 1 -n 10 -o cpu -stats pid,command,cpu,mem 2>/dev/null | tail -12
```

Notes:
- `memory_pressure` reports a free percentage and is the closest analogue to
  Linux PSI; there is no `/proc/pressure` on macOS.
- `powermetrics` requires root and is skipped when `sudo -n` fails.

### E. Updates

Intentionally out of scope. Do not run update checks; state this under FINDINGS.

## Conditional bundles (only if supported)

### F. Power, thermal, network

Laptops have a battery; desktops may report AC only.

```sh
pmset -g batt 2>/dev/null
pmset -g ps 2>/dev/null
pmset -g assertions 2>/dev/null
system_profiler SPPowerDataType 2>/dev/null |
  grep -Ei 'cycle count|condition|charge|capacity|health|maximum'
pmset -g therm 2>/dev/null
pmset -g log 2>/dev/null | grep -Ei 'wake|sleep|fail' | tail -20
```

Network:

```sh
ifconfig 2>/dev/null
networksetup -listallhardwareports 2>/dev/null
scutil --dns 2>/dev/null | head -30
netstat -s 2>/dev/null | grep -Eai 'bad|drop|error'
system_profiler SPAirPortDataType 2>/dev/null | grep -Ei 'status|signal|channel|phy'
```

Notes:
- `powermetrics --samplers thermal,cpu_power -n 1 -i 1000` needs root; print it for
  manual use when `sudo -n` fails.
- Sleep/wake blockers named `AirDrop` or third-party remote tools are usually
  intentional; report as INFO/NOISE, not faults.

### G. Security-light

```sh
fdesetup status 2>/dev/null
csrutil status 2>/dev/null
spctl --status 2>/dev/null
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null
who 2>/dev/null
last -n 10 2>/dev/null
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null
```

Privileged/manual when `sudo -n` is unavailable:

```sh
sudo /usr/bin/log show --last 1h --style compact --predicate 'process == "sudo"'
sudo lsof -nP -iTCP -sTCP:LISTEN
sudo systemsetup -getremotelogin
sudo pfctl -s info
```

### H. Integrity and hygiene

```sh
tmutil destinationinfo 2>/dev/null
tmutil latestbackup 2>/dev/null
systemextensionsctl list 2>/dev/null
pkgutil --pkgs 2>/dev/null | wc -l
command -v brew >/dev/null && brew doctor 2>/dev/null | head -30
```

## Severity rubric

- **CRIT** - functional impact, data risk, or security exposure (kernel panic,
  Jetsam kill storm, failed third-party launch jobs, disk full, SMART failure,
  unauthorized access).
- **WARN** - degradation likely to matter (low disk, rising error counters,
  repeated service failures, FileVault off on a laptop, firewall off, stale
  system extensions waiting to uninstall).
- **INFO** - noteworthy but harmless (no Time Machine destination, `-9` on-demand
  agents, sleep assertions, deprecated settings, cosmetic assertions).
- **NOISE** - high-volume log spam with no functional impact. Report source,
  volume, and first/last seen, and keep it out of the problem list.

## Report format requirements

Plain text only. No markdown headings, tables, or bold.

**Header (exactly three lines, then a blank line):**

```
System log maintenance - <YYYY-MM-DD>
Host: <hostname> (<macOS version>, <chip/model>)
Monitoring window: last <N> <unit>
```

**Sections** - uppercase labels on their own line, no colon:
`FINDINGS`, `CAUSE`, `ACTION`.

**FINDINGS**

- Use `- ` bullets, hard-wrapped at about 78 columns with continuation lines
  indented two spaces.
- The **first bullet is the overall assessment**: normal/degraded plus what was
  clean, before any warnings.
- Put severity inline as a prefix: `- WARN: ...`, `- CRIT: ...`, `- INFO: ...`,
  `- NOISE: ...`. No separate severity column.
- Label carried-over items with their age: `- WARN (carried since <date>): ...`.
- Include trends and deltas whenever a prior entry exists: `(was 93% on Oct 13/19)`,
  `(+91)`, `unchanged since Sep`.
- Quantify everything: counts over the window, percentages, temperatures, units
  (`544 warnings/4d`, `28C`, `8.7 GiB`).
- Collapse all spam into **one NOISE bullet**, grouped by source/class, with
  volume and explanation. Never mix noise into WARN/CRIT.
- State that system updates are out of scope.
- Reference prior entries by date so consecutive reports read as a series.

**CAUSE**

- Short causal bullets. Say explicitly when a reading is an unconfirmed single
  measurement, and when noise has no functional impact.

**ACTION**

- Imperative bullets, one per decision or follow-up. Include open decisions with
  their age (`open since <date>`).

**Closing line (always last):**

```
No remediation performed. Privileged results supplied by the user.
```

Use `No remediation performed. Privileged checks skipped - manual commands above.`
when sudo was unavailable and privileged checks were not run.

## Maintenance log

- Directory: `~/Documents/OS-maintenance/` (create with `mkdir -p` if missing).
- File: `<YYYY-MM-DD>.txt` from `date +%Y-%m-%d`.
- Content: the same plain-text FINDINGS/CAUSE/ACTION block above. Same format as
  historical entries - no markdown, no tables.
- **Write only after the user confirms.** Show the drafted entry first. If the
  file already exists, append.

## Notes

- Restart opencode after creating or editing a skill so it is reloaded.
- Benign patterns live per-machine in
  `~/.config/system-health-check-mac/benign.txt` (optional). Keep machine-specific
  noise out of this skill body.
