# Notebook AI setup

`howto ask <topic> "<query>"` concatenates the matched notebook topic(s) and pipes them through an AI helper. The helper is selected by `$NOTEBOOK_AI`.

## Quick start: local Gemma 4 via Ollama (recommended)

    brew install ollama
    open -a Ollama                       # first launch installs the CLI shim
    ollama pull gemma4:e2b-mlx           # ~7 GB on disk; Apple Silicon MLX build
    export NOTEBOOK_AI=ollama

Persist the export by adding the line to `aliases/secrets/secrets` (auto-loaded, gitignored).

Test:

    howto ask awk "explain the gsub example"

## Model tags vs. RAM (Apple Silicon, Q4)

| Tag              | Disk  | Resident | 18 GB Mac |
|------------------|-------|----------|-----------|
| gemma4:e2b-mlx   | 7 GB  | ~5-6 GB  | easy      |
| gemma4:e4b-mlx   | 11 GB | ~9-11 GB | tight     |
| gemma4:26b       | 16 GB | ~18+ GB  | swap      |
| gemma4:31b       | 20 GB | ~22+ GB  | no        |

Override default with `export OLLAMA_MODEL=gemma4:e4b-mlx`.

Cap context to control KV-cache RAM growth:

    export OLLAMA_CONTEXT_LENGTH=8192    # default is the model's max (up to 128k)

## Other providers

| Value of `NOTEBOOK_AI` | Backend                                      |
|------------------------|----------------------------------------------|
| `claude` (default)     | `claudio` shell function, else `claude` CLI  |
| `opencode`             | `opencode` CLI (lazy-loaded)                 |
| `lms`                  | LM Studio CLI (lazy-loaded)                  |
| `ollama`               | `ollama run "$OLLAMA_MODEL"`                 |

## Silence the one-time setup hint

    touch ~/.cache/notebook-ai-hint
