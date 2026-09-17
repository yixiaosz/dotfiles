---
name: system-health-check
description: Run a read-only system health check on an Ubuntu/Debian systemd machine (desktop, laptop, or server), scan recent logs for error/warning spam, and write a dated maintenance report. Use when asked to check system status, review logs, diagnose log spam or recurring warnings, or perform routine OS maintenance.
---

# System Health Check

A repeatable, **read-only** health check for Ubuntu/Debian machines running
systemd. It detects what the current host actually supports, runs only the
relevant checks, ranks findings by severity, and optionally writes a dated
entry to the maintenance log.

## Principles

- **Read-only by default.** Never remediate, install, purge, or edit anything
  unless the user explicitly asks. Diagnose, then propose.
- **Capability-gated.** A desktop, laptop, and headless server share one skill;
  detect tools/hardware first and skip what is absent.
- **Be defensive.** Any command may be missing or require privileges. Guard
  with `command -v`, handle failures, and record what was skipped and why.
- **Bound every log query.** Always pass `--since` to `journalctl`. Full-journal
  scans are enormous and will time out. Use `grep -a` on log files (some are
  treated as binary).
- **Stable parsing.** Prefix data-parsing commands with `LC_ALL=C`.
- **One privileged attempt.** Try `sudo -n` once; this environment has no TTY,
  so an interactive password prompt cannot be answered. If it fails, skip the
  privileged checks and print the exact commands for the user to run manually.
- **Report noise separately.** GUI/GTK/desktop log spam with no functional
  impact is "log noise", not a fault. Do not present it as a problem.

## Step 0 - Preflight (capability detection)

Gather context and decide which bundles apply:

```sh
date; hostname; uptime; id -u; sudo -n true 2>/dev/null && echo "sudo:ok" || echo "sudo:no"
```

Detect form factor and tools:

```sh
ls -d /sys/class/power_supply/BAT* 2>/dev/null || echo "no battery"
for c in jq python3 sensors nmcli iw ufw nft iptables snap flatpak smartctl \
         upower tlp lspci ss timedatectl xdg-user-dir; do
  printf '%-14s ' "$c"; command -v "$c" 2>/dev/null || echo -
done
```

Detect block devices (filter out loops and roms):

```sh
lsblk --json -d -o NAME,TYPE,ROTA,MODEL 2>/dev/null
```

Record the capability matrix. Any check whose tools are missing is reported as
"skipped (tool absent)" rather than failing the run.

## Core checks (always)

### A. Logs

Priority counts over the chosen window (default last 4 days; adjust to the
user's ask):

```sh
for p in 0 1 2 3; do
  printf 'prio %s: ' "$p"
  journalctl --since "4 days ago" -p "$p" --no-pager -o cat 2>/dev/null | wc -l
done
```

Top spam sources by unit. Cascade `jq` -> `python3` -> `awk`:

```sh
journalctl --since "4 days ago" -p warning --no-pager -o json 2>/dev/null |
  jq -r '(._SYSTEMD_UNIT // .SYSLOG_IDENTIFIER // ._COMM // "unknown")' |
  sort | uniq -c | sort -rn | head -25
```

If `jq` is absent, substitute an `awk` JSON-free fallback, e.g.:

```sh
journalctl --since "4 days ago" -p warning --no-pager 2>/dev/null |
  awk '{print $5}' | sort | uniq -c | sort -rn | head -25
```

Critical/alert entries and the dominant messages from the noisiest unit:

```sh
journalctl --since "4 days ago" -p 2 --no-pager -o short-precise 2>/dev/null
journalctl --since "4 days ago" _SYSTEMD_UNIT=<unit> -p warning --no-pager -o cat 2>/dev/null
```

OOM / disk I/O / hardware errors:

```sh
journalctl --since "4 days ago" -k --no-pager 2>/dev/null | grep -aEi 'I/O error|oom-kill|out of memory|EXT4-fs error|medium error|SATA link down'
```

Auth failures (see also bundle G). If the journal is not fully readable, fall
back to log files that are readable:

```sh
for f in /var/log/syslog /var/log/kern.log /var/log/auth.log; do
  [ -r "$f" ] && echo "$f: readable" || echo "$f: not readable"
done
```

**Benign filtering:** if `~/.config/system-health-check/benign.txt` exists, read
it (one regex per line, `#` comments allowed) and exclude messages matching any
pattern from the spam ranking; report the suppressed count separately.

### B. Units and boot

```sh
systemctl --failed --no-pager
systemctl is-system-running 2>/dev/null
systemd-analyze 2>/dev/null
systemd-analyze blame 2>/dev/null | head -10
```

### C. Storage

```sh
df -hP -x tmpfs -x devtmpfs -x squashfs
df -iP -x tmpfs -x devtmpfs -x squashfs
journalctl --disk-usage 2>/dev/null
```

SMART per discovered device (privileged; requires `smartctl` and root). Build
the device list from `lsblk` (`NAME` for `disk` type, excluding loops/roms) so
NVMe (`/dev/nvme0n1`) and eMMC (`/dev/mmcblk0`) are handled:

```sh
sudo -n smartctl -H -A "/dev/$dev" 2>/dev/null
```

### D. Memory and CPU

```sh
free -h
ps -eo pcpu,pmem,pid,comm --sort=-pcpu 2>/dev/null | head -12
cat /proc/pressure/cpu /proc/pressure/io /proc/pressure/memory 2>/dev/null
```

### E. Updates and patching

```sh
ls -l /var/lib/apt/periodic/update-success-stamp 2>/dev/null
apt list --upgradable 2>/dev/null | tail -n +2 | head
ls -l /var/run/reboot-required /run/reboot-required 2>/dev/null || echo "no reboot required"
tail -3 /var/log/unattended-upgrades/unattended-upgrades.log 2>/dev/null
command -v snap >/dev/null && snap refresh --list 2>/dev/null
command -v flatpak >/dev/null && flatpak remote-ls --updates 2>/dev/null
```

## Conditional bundles (only if supported)

### F. Power, thermal, network (laptops and/or wireless hosts)

Only if `/sys/class/power_supply/BAT*` exists:

```sh
command -v upower >/dev/null && upower -i "$(upower -e 2>/dev/null | grep -m1 BAT)" 2>/dev/null
for b in /sys/class/power_supply/BAT*; do
  printf '%s: %s%% %s\n' "$b" "$(cat "$b/capacity" 2>/dev/null)" "$(cat "$b/status" 2>/dev/null)"
done
command -v tlp >/dev/null && tlp-stat -b 2>/dev/null
```

Thermals - prefer `sensors`, else sysfs:

```sh
if command -v sensors >/dev/null; then sensors 2>/dev/null; else
  for z in /sys/class/thermal/thermal_zone*; do
    printf '%s %s\n' "$(cat "$z/type" 2>/dev/null)" "$(cat "$z/temp" 2>/dev/null)"
  done
fi
```

Network - `nmcli`/`iw` if present, else `ip` + sysfs stats:

```sh
command -v nmcli >/dev/null && nmcli -t -f DEVICE,STATE,SIGNAL dev wifi 2>/dev/null
command -v iw >/dev/null && iw dev 2>/dev/null
for i in /sys/class/net/*; do
  n=$(basename "$i")
  printf '%s rx_err=%s tx_err=%s\n' "$n" \
    "$(cat "$i/statistics/rx_errors" 2>/dev/null)" \
    "$(cat "$i/statistics/tx_errors" 2>/dev/null)"
done
command -v timedatectl >/dev/null && timedatectl 2>/dev/null
```

### G. Security-light

```sh
grep -aEi 'Failed|Invalid|authentication failure|BREAK-IN' /var/log/auth.log 2>/dev/null | tail -20
last -n 10 2>/dev/null
sudo -n lastb -n 10 2>/dev/null
ss -tulpn 2>/dev/null
if command -v ufw >/dev/null; then sudo -n ufw status 2>/dev/null
elif command -v nft >/dev/null; then sudo -n nft list ruleset 2>/dev/null
else sudo -n iptables -S 2>/dev/null; fi
```

### H. Integrity and hygiene

```sh
dpkg --audit 2>/dev/null
apt-mark showhold 2>/dev/null
systemctl list-timers --all --no-pager 2>/dev/null | head -20
```

## Severity rubric

- **CRIT** - functional impact, data risk, or security exposure (failed units,
  degraded system, disk full/inodes, SMART failure, unauthorized access).
- **WARN** - degradation likely to matter (patching overdue, low disk, rising
  error counters, repeated service failures).
- **INFO** - noteworthy but harmless (transient firmware messages, deprecated
  settings, cosmetic assertions).
- **NOISE** - high-volume log spam with no functional impact. Report source,
  volume, and first/last seen, and keep it out of the problem list.

## Report template

```
# System Health Report - <YYYY-MM-DD>
Host: <hostname> (<distro>, uptime, form factor)

## Summary
<one or two lines: overall state, top finding, anything CRIT>

## Findings (ranked)
1. [SEVERITY] <source> - <count> events, first <ts> / last <ts>
   Cause: <root cause>
   Action: <recommended action or "none - noise">

## Skipped / unavailable
<checks skipped and why (tool absent, needs sudo, not applicable)>

## Privileged commands to run manually (if sudo unavailable)
<ready-to-paste commands>
```

## Maintenance log

- Directory: `~/Documents/OS-maintenance/` (create with `mkdir -p` if missing).
- File: `<YYYY-MM-DD>.txt` from `date +%Y-%m-%d`.
- Content: a **brief** plain-text entry - Findings, Cause, Action. Same format
  as historical entries.
- **Write only after the user confirms.** If the file already exists, append.
- Show the drafted entry before writing.

## Notes

- Restart opencode after creating or editing a skill so it is reloaded.
- Benign patterns live per-machine in `~/.config/system-health-check/benign.txt`
  (optional). Keep machine-specific noise out of this skill body.
