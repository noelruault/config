# Every package setup installs. `setup.sh init` installs what is missing, `setup.sh update` also upgrades, `setup.sh doctor` reports what is absent.

tap "noelruault/tap"

brew "bash"       # current bash; macOS ships 3.2
brew "git"        # version control and the private-repo clones
brew "gh"         # GitHub CLI: auth, private clones, PR and workflow operations
brew "python"     # python3 for bin/resolve-secrets in the .claude dotfiles repo
brew "awscli"     # the AWS read-only guard and day-to-day AWS
brew "coreutils"  # gdate gives zshrc/log its millisecond timing
brew "fzf"
brew "shfmt"
brew "shellcheck"
brew "neovim"     # config in nvim/; lazy.nvim fetches plugins on first launch
brew "ffmpeg"     # bin/to-webm
brew "webp"       # cwebp for bin/to-webp
# Homebrew refuses formulae from a tap nobody trusted yet, which is every tap on a fresh machine. This trusts the one formula, not the whole tap.
brew "noelruault/tap/lazyaws", trusted: true
