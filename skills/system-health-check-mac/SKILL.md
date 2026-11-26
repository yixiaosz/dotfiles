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
  unless the user explicitly asks. Diagnose, then propose. Remove temporary log
  captures after parsing; maintenance-log writes still require confirmation.
- **Capability-gated.** Laptop and desktop share one skill; detect optional tools
  and hardware first and skip what is absent.
- **Be defensive.** Any command may be missing or require privileges. Guard with
  `command -v`, handle failures, and record what was skipped and why.
- **Always use `/usr/bin/log`.** `log` is a zsh builtin on this platform; invoke
  `/usr/bin/log` explicitly.
- **Bound every log query.** The default detailed window is **1 hour**. Always
  pass `--last` and a `--predicate`, and use `--style ndjson` for parsing. Scan
  older history only when necessary to establish an identified finding's onset
  or duration, or when the user explicitly confirms. Older scans must use narrow
  process/subsystem/message predicates and return aggregates or small samples.
- **Stable parsing.** Prefix data-parsing commands with `LC_ALL=C`.
- **One privileged workflow.** Probe `sudo -n` once during preflight. If it
  fails, never repeat probes that add noise to the authentication log. If it
  succeeds, run the consolidated checks noninteractively without retrying
  failures.
- **Triage before deep-diving.** Run one compact core snapshot, then investigate
  only new, worsened, carried, or user-requested findings.
- **Report noise separately.** Classify chatter as NOISE only when it is
  transient or explained and has no functional impact. A sustained, concentrated
  retry loop remains WARN even when the Mac feels normal.
- **System updates are out of scope.** Do not run `softwareupdate` or
  `brew outdated`; state this once under FINDINGS.

## Step 0.5 - Prior baseline (read before running checks)

```sh
ls -1 ~/Documents/OS-maintenance/*.txt 2>/dev/null | sort -r | head -1
```

Read the latest dated entry. Consult older entries only when a carried finding
needs its original context. Carry forward open actions and compare relevant
metrics, evaluating material trends alongside absolute thresholds. If no entries
exist, use `template.txt` in this skill's directory and include
`INFO: no baseline - first run` under FINDINGS.

## Step 0 - Preflight (capability detection)

```sh
date; hostname; sw_vers; uname -m; uptime; id -u
sudo -n true 2>/dev/null && echo "sudo:ok" || echo "sudo:no"
sysctl -n hw.model hw.memsize kern.boottime
pmset -g batt 2>/dev/null
for c in jq python3 brew; do
  printf '%-10s ' "$c"; command -v "$c" 2>/dev/null || echo -
done
diskutil info / 2>/dev/null
```

If sudo is available, run the equivalent checks below once with `sudo -n` and
record failures without retrying. If sudo is unavailable, immediately give the
user this consolidated block and continue the unprivileged checks without
further sudo attempts. Incorporate any returned output before drafting.

```sh
sudo /usr/bin/log show --last 1h --style compact --predicate 'process == "sudo"'
sudo lsof -nP -iTCP -sTCP:LISTEN
sudo systemsetup -getremotelogin
sudo pfctl -s info
sudo powermetrics --samplers thermal,cpu_power -n 1 -i 1000
```

Record skipped checks and why. Do not inventory standard macOS tools before
using them; guard only optional or missing commands.

## Core checks (always)

### A. Logs (unified log)

Capture the broad window once, then derive every routine summary from the
cached NDJSON instead of rescanning the unified log:

```sh
WINDOW="${WINDOW:-1h}"
LOG_FILE="$(mktemp -t system-health-check-log.XXXXXX)"
trap 'rm -f "$LOG_FILE"' EXIT HUP INT TERM
/usr/bin/log show --last "$WINDOW" --style ndjson \
  --predicate 'messageType == error OR messageType == fault' \
  >"$LOG_FILE" 2>/dev/null
```

Counts and top sources:

```sh
LC_ALL=C jq -r '.messageType // "unknown"' "$LOG_FILE" | sort | uniq -c
LC_ALL=C jq -r '(.process // .subsystem // .senderImagePath // "unknown")' \
  "$LOG_FILE" | sort | uniq -c | sort -rn | head -15
```

Fault samples and kernel/hardware warnings:

```sh
LC_ALL=C jq -r 'select((.messageType | tostring | ascii_downcase) == "fault") |
  [.timestamp, (.process // "unknown"), .eventMessage] | @tsv' \
  "$LOG_FILE" | tail -20
LC_ALL=C jq -r 'select(.process == "kernel") | .eventMessage' "$LOG_FILE" |
  grep -aEi 'I/O error|panic|watchdog|SMC|thermal|throttle|disk|NVMe'
```

If the capture fails or `jq` is unavailable, report unified-log checks as
skipped; never interpret an empty capture as zero errors. If
`~/.config/system-health-check-mac/benign.txt` exists, apply its patterns while
summarizing the cached entries. Report total, suppressed, and residual counts
plus the top residual sources. Derive first/last timestamps and representative
messages for dominant findings from the same capture. Treat unmatched
high-volume chatter as unclassified until its duration and impact are assessed;
do not automatically call it benign.

Diagnostic reports retain their four-day window:

```sh
find /Library/Logs/DiagnosticReports -maxdepth 1 -name '*.ips' \
  -newermt '-4 days' -print 2>/dev/null | head -20
```

Inspect only the returned reports for Jetsam or panic details. Authentication
queries belong in targeted security deep-dives, not this broad capture.

Remove the capture as soon as all summaries and samples are derived:

```sh
rm -f "$LOG_FILE"
trap - EXIT HUP INT TERM
unset LOG_FILE
```

### B. Services and boot

```sh
launchctl list 2>/dev/null | awk 'NR>1 && $1=="-" && $2!="0" {print $1, $2, $3}'
systemextensionsctl list 2>/dev/null
pmset -g stats 2>/dev/null
```

Notes:
- `launchctl list` columns are `PID Status Label`. `PID == "-"` means not running;
  a non-zero `Status` is the last exit code. `-9` is SIGKILL and is common for
  on-demand system agents - treat as INFO unless a third-party label is involved.
- System extensions stuck in `terminated waiting to uninstall on reboot` are WARN.
- Inventory LaunchAgents/LaunchDaemons only for a failed or suspicious job. Do
  **not** enumerate login items with `osascript`; its Automation/TCC prompt hangs
  in a non-interactive session.

### C. Storage

```sh
df -hP / 2>/dev/null
diskutil info disk0 2>/dev/null |
  grep -Ei 'device / media name|smart|solid state|capacity|file system'
mdutil -s / 2>/dev/null
```

Notes:
- `diskutil info <disk>` reports `SMART Status: Verified` without root. Map the
  boot disk first (`diskutil info /`), then check its physical store; `disk0` is
  the common case on Apple Silicon.
- APFS inode counts are not meaningful; skip `df -i`.
- Run `diskutil apfs list`, `system_profiler SPStorageDataType`, or
  `tmutil listlocalsnapshots /` only for low-disk, purgeable-space, or snapshot
  findings.

### D. Memory and CPU

```sh
memory_pressure 2>/dev/null | tail -5
sysctl vm.swapusage 2>/dev/null
sysctl -n vm.loadavg 2>/dev/null
ps -Ao pcpu,pmem,pid,comm -r 2>/dev/null | head -12
```

Notes:
- `memory_pressure` reports a free percentage and is the closest analogue to
  Linux PSI; there is no `/proc/pressure` on macOS.
- Add `vm_stat` or a one-sample `top` only when pressure, swap, or load is
  abnormal. `powermetrics` is covered by the preflight privileged block.

### E. Updates

Intentionally out of scope. Do not run update checks; state this under FINDINGS.

## Baseline and targeted bundles

Run battery checks on laptops and security/backup state on every host. Use the
remaining commands only for a user request, baseline anomaly, open action, or
core finding.

### F. Power, thermal, network

Laptop baseline:

```sh
pmset -g batt 2>/dev/null
system_profiler SPPowerDataType 2>/dev/null |
  grep -Ei 'cycle count|condition|charge|capacity|health|maximum'
pmset -g therm 2>/dev/null
```

Sleep/wake or network deep-dives:

```sh
pmset -g assertions 2>/dev/null
pmset -g log 2>/dev/null | grep -Ei 'wake|sleep|fail' | tail -20
ifconfig 2>/dev/null
networksetup -listallhardwareports 2>/dev/null
scutil --dns 2>/dev/null | head -30
netstat -s 2>/dev/null | grep -Eai 'bad|drop|error'
system_profiler SPAirPortDataType 2>/dev/null | grep -Ei 'status|signal|channel|phy'
```

Sleep/wake blockers named `AirDrop` or third-party remote tools are usually
intentional; report them only when relevant.

### G. Security-light

Baseline state:

```sh
fdesetup status 2>/dev/null
csrutil status 2>/dev/null
spctl --status 2>/dev/null
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null
```

For an authentication/listener concern or explicit user request only:

```sh
/usr/bin/log show --last "$WINDOW" --style compact \
  --predicate 'process == "authd" OR process == "sshd" OR process == "sudo"' \
  2>/dev/null | grep -aEi 'fail|invalid|denied|authentication'
last -n 10 2>/dev/null
who 2>/dev/null
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null
```

Do not rerun the privileged commands from preflight; use the user's output.

### H. Integrity and hygiene

```sh
tmutil destinationinfo 2>/dev/null
```

Run `tmutil latestbackup` only when a destination is configured. Run
`pkgutil --pkgs` or `brew doctor` only for a package/Homebrew finding or explicit
request; these inventories are not routine health metrics and do not change the
updates-out-of-scope rule.

## Severity rubric

- **CRIT** - functional impact, data risk, or security exposure (kernel panic,
  Jetsam kill storm, failed third-party launch jobs, disk full, SMART failure,
  unauthorized access).
- **WARN** - degradation likely to matter (low disk, rising error counters,
  repeated service failures, FileVault off on a laptop, firewall off, stale
  system extensions waiting to uninstall).
- **INFO** - noteworthy but harmless (no Time Machine destination, `-9` on-demand
  agents, sleep assertions, deprecated settings, cosmetic assertions).
- **NOISE** - transient or explained high-volume spam with no functional impact.
  Report source, volume, and first/last seen, and keep it out of the problem
  list. Sustained retry loops are WARN, not NOISE.

## Report format requirements

Plain text only. No markdown headings, tables, or bold. Aim for 30-45 lines,
excluding manual command blocks and same-day UPDATES.

**Header (exactly three lines, then a blank line):**

```
System log maintenance - <YYYY-MM-DD>
Host: <hostname> (<macOS version>, <chip/model>)
Monitoring window: last <N> <unit>
```

**Sections** - uppercase labels on their own line, no colon:
`FINDINGS`, `CAUSE`, `ACTION`; optional `UPDATES` for same-day follow-ups.

**FINDINGS**

- Use `- ` bullets, hard-wrapped at about 78 columns with continuation lines
  indented two spaces.
- The **first bullet is the overall assessment**: normal/degraded plus the top
  finding, without enumerating every clean check.
- Put severity inline as a prefix: `- WARN: ...`, `- CRIT: ...`, `- INFO: ...`,
  `- NOISE: ...`.
- Combine healthy storage/SMART, memory/swap, battery/thermal, and security
  state into one INFO baseline bullet. Omit unchanged network, listener, and
  package inventories unless relevant to a finding or user request.
- Label carried items with their age and current status in one bullet. Do not
  repeat their original root-cause history.
- Quantify findings and material deltas with counts, rates, units, and prior
  dates. Do not quantify stable details merely because they were collected.
- Collapse confirmed spam into **one NOISE bullet** with total, suppressed, and
  residual volume, top sources, duration, and impact. Keep sustained retry loops
  in WARN/CRIT rather than hiding them in NOISE.
- State once that system updates are out of scope. Reference prior entries only
  for carried, resolved, or materially changed findings.

**CAUSE**

- Use short bullets only for new, worsened, or non-obvious findings. Identify
  unconfirmed single measurements; do not restate healthy states or noise
  explanations already covered by FINDINGS.

**ACTION**

- List only new or still-open follow-ups, with their age. Verify, close, or
  escalate carried actions instead of copying them forward indefinitely.

**Closing line (always last):**

```
No remediation performed by this check. Privileged results supplied by the user.
```

When sudo was unavailable and privileged checks were not run, use:

```
No remediation performed by this check. Privileged checks skipped - manual commands above.
```

## Maintenance log

- Directory: `~/Documents/OS-maintenance/` (create with `mkdir -p` if missing).
- File: `<YYYY-MM-DD>.txt` from `date +%Y-%m-%d`.
- Content: the same plain-text FINDINGS/CAUSE/ACTION block above. Follow the
  most recent historical entry's header, section names, and wrapping; when no
  entries exist, use `template.txt` in this skill's directory.
- For same-day rechecks or user-performed actions, append a short `UPDATES`
  block with timestamped bullets instead of another full report. Finish with
  the applicable closing line so it remains last.
- **Write only after the user confirms.** Show the drafted entry or update
  before writing.

## Notes

- Restart opencode after creating or editing a skill so it is reloaded.
- Benign patterns live per-machine in
  `~/.config/system-health-check-mac/benign.txt` (optional). Keep machine-specific
  noise out of this skill body.
