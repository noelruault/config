# config

```bash
cd && git clone https://github.com/noelruault/config.git && config/setup.sh init
```

| Command | What it does |
|---|---|
| `setup.sh` | print the commands; changes nothing |
| `setup.sh init` | install everything; safe to run again |
| `setup.sh update` | pull this repo, then update every component and upgrade the Brewfile packages |
| `setup.sh doctor` | check every component; exits 1 when a required one is broken |
| `setup.sh components` | list what setup manages, in run order |

Once installed, `cfg` is `setup.sh` from any directory: `cfg doctor`, `cfg update`.

Options: `--dry-run` prints the plan and changes nothing, `--only a,b` and `--skip a,b` pick components, `--yes` accepts every yes/no prompt.

Packages live in [`Brewfile`](Brewfile). Everything else setup does is one file in [`setup/components/`](setup/components). Rules for changing the code are in [`GUIDELINES.md`](GUIDELINES.md); `tests/run.sh` enforces the ones a machine can decide.
