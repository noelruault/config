#!/usr/bin/env zsh
# startup-waterfall — show WHERE zsh startup time goes.
#
# Traces a real login+interactive shell (your actual ~/.zshrc) with microsecond
# timestamps via xtrace, then prints the biggest time gaps between trace steps —
# a chronological "waterfall" of what's slow. CPU-bound steps (compinit, plugin
# parsing) show up as large gaps on the line that triggered them.
#
# Usage: zsh startup-waterfall.sh
set -e
real_home=$HOME
tmp=$(mktemp -d)

cat > "$tmp/.zshrc" <<EOF
zmodload zsh/datetime
setopt prompt_subst
PS4='+\${EPOCHREALTIME} %N:%i> '
setopt xtrace
source "$real_home/.zshrc"
unsetopt xtrace
EOF
[[ -f "$real_home/.zprofile" ]] && cp "$real_home/.zprofile" "$tmp/.zprofile"

ZDOTDIR="$tmp" HOME="$real_home" zsh -il -c exit 2> "$tmp/trace.log" || true

python3 - "$tmp/trace.log" <<'PY'
import sys, re, collections
ev = []
for ln in open(sys.argv[1], encoding='utf-8', errors='replace'):
    m = re.match(r'\++([0-9]+\.[0-9]+) (.*)', ln)
    if m:
        ev.append((float(m.group(1)), m.group(2)))
if len(ev) < 2:
    print("no timed trace captured"); sys.exit()
total = ev[-1][0] - ev[0][0]

# Attribute each step's cost to its "owner" (the sourced file or function that
# ran it), so we get a per-subsystem waterfall instead of thousands of lines.
agg = collections.defaultdict(lambda: [0.0, 0])
for i in range(1, len(ev)):
    d = ev[i][0] - ev[i-1][0]
    ctx = ev[i-1][1]
    mo = re.match(r'([^ ]+):\d+>', ctx)          # "path-or-func:line> cmd"
    owner = mo.group(1) if mo else ctx.split('>')[0].strip()
    owner = owner.split('/')[-1] or owner         # basename for paths
    a = agg[owner]; a[0] += d; a[1] += 1

rows = sorted(agg.items(), key=lambda kv: -kv[1][0])[:18]
print(f"\nstartup waterfall — total {total*1000:.0f} ms, by subsystem "
      f"(xtrace adds overhead; read it RELATIVELY)\n")
print(f"{'cost(ms)':>9} {'%':>5} {'steps':>7}  subsystem")
print("-"*78)
for owner, (cost, n) in rows:
    pct = cost/total*100
    bar = '#' * max(1, int(pct/2))
    print(f"{cost*1000:9.1f} {pct:5.1f} {n:7d}  {bar:<26} {owner[:34]}")
PY
rm -rf "$tmp"
