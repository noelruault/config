# bin

Scripts symlinked into `~/.local/bin` by `setup.sh`, which sits ahead of `/opt/homebrew/bin` on PATH. Editing one here takes effect immediately; there is nothing to rebuild or reinstall.

## cfg

`setup.sh` from any directory: `cfg doctor`, `cfg update`, `cfg init --only bin_links`. It takes exactly what `setup.sh` takes. Not named `dot`, because Graphviz installs a `dot` and this directory wins on PATH.

## default-editor

Makes shell scripts (`.sh`, `.bash`, `.zsh`, ...) open in whatever app opens plain text, instead of the terminal that registers for them (Ghostty claims `public.shell-script`).

```sh
default-editor          # point every script type at the current plain-text app
default-editor Zed      # set the plain-text app to Zed (/Applications or /System/Applications name, or a .app path), then sync
default-editor --show   # print which app opens each type, change nothing
```

`public.plain-text` is the macOS type for `.txt`, so its default app is the nearest thing macOS has to a system-wide default editor. `setup.sh` sets it to Zed and installs a LaunchAgent (`com.noelruault.default-editor`) that re-runs the sync whenever LaunchServices' handler plist changes, so a Finder "Get Info > Open with > Change All" on a `.txt` carries scripts with it. Errors go to `~/Library/Logs/default-editor.log`.

An app that does not declare it can open scripts (TextEdit) is refused by macOS (`The file couldn’t be opened`), and scripts stay on their previous app.

It uses `NSWorkspace.setDefaultApplication`; the older `LSSetDefaultRoleHandlerForContentType` returns success on current macOS and changes nothing.
