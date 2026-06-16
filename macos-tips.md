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
