# macOS tips

## Local LLMs / Ollama

Bump GPU (Metal) wired memory limit so big models get more of the 24GB unified RAM.
Default cap ~75% of RAM. Temporary (resets on reboot):

```bash
# allow ~20GB to GPU (value in MB). 24GB Mac.
sudo sysctl iogpu.wired_limit_mb=20480
```

Wrapped as `gpu-max [MB]` (default 20480) in `zshrc/aliases/os/macos`.
Make permanent: add a LaunchDaemon, or re-run after boot.

Best local coding model on this box (M5 Pro, 24GB), June 2026:
```bash
ollama pull qwen3-coder:30b   # MoE, 30B total / 3B active, Q4 ~19GB
```

Wired into `aispeak` + notebook `howto ask` via `OLLAMA_MODEL` + `NOTEBOOK_AI=ollama`
(both exported in `zshrc/zprofile`).

Monitor: `sudo asitop` or Activity Monitor.

## Colima won't start: "in use by instance colima"

Symptom: `colima start` dies with
`error at 'starting': exit status 1`, hostagent log says
`failed to run attach disk "colima", in use by instance "colima"`.
`colima stop` may lie and say `not running`.

Cause: colima's named external data disk
(`~/.colima/_lima/_disks/colima/`) is locked by a symlink `in_use_by`,
created on attach and deleted on clean shutdown. An unclean death
(crash, `kill -9`, hard reboot, sleep while running) leaves it dangling →
restart aborts before the VM boots. CPU/mem flags never get read.

Real error is in `~/.colima/_lima/colima/ha.stderr.log`, not the terminal.

Diagnose (confirm stale lock, not a live VM):
```bash
ps aux | grep -Ei 'limactl|colima|vz|qemu' | grep -v grep   # only orphans? safe
ls -la ~/.colima/_lima/_disks/colima/in_use_by              # dangling symlink = it
```

Fix (only when NO live VM holds the disk):
```bash
ps aux | grep -Ei 'limactl usernet|colima daemon' | grep -v grep | awk '{print $2}' | xargs -r kill
rm -f ~/.colima/_lima/_disks/colima/in_use_by   # symlink, not data; lima recreates on attach
colima start --cpu 6 --memory 12
```

Prevention: always `colima stop` before sleep/reboot; never `kill -9`.
Recur = same one-liner: `rm -f ~/.colima/_lima/_disks/colima/in_use_by && colima start`.
