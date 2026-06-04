# vim

Modal editor. Reference corpus for the offline notebook and the `vimvoice` voice assistant.

## Modes

- `i` insert before cursor, `a` after, `I` start of line, `A` end of line.
- `o` open line below, `O` above.
- `Esc` / `Ctrl-[` back to normal mode.
- `v` visual (char), `V` visual line, `Ctrl-v` visual block.
- `R` replace mode. `:` command-line mode.

## Motions

- `h j k l` left/down/up/right. `w` next word, `b` back word, `e` end of word.
- `0` line start, `^` first non-blank, `$` line end.
- `gg` top of file, `G` bottom, `:42` or `42G` go to line 42.
- `f<c>` jump to next `<c>` on line, `t<c>` till before it; `;`/`,` repeat.
- `{` `}` paragraph back/forward. `%` matching bracket.
- `Ctrl-d`/`Ctrl-u` half-page down/up. `Ctrl-f`/`Ctrl-b` full page.
- `H M L` top/middle/bottom of screen. `zz` center cursor line.

## Editing (operators + motions compose)

- `d` delete, `c` change (delete + insert), `y` yank (copy), `>`/`<` indent.
- Operator + motion: `dw` delete word, `d$` to end of line, `dd` whole line.
- Text objects: `iw` inner word, `aw` a word, `i"` inside quotes, `ip` paragraph,
  `it` inside tag. e.g. `ci"` change inside quotes, `dap` delete a paragraph.
- `x` delete char, `r<c>` replace one char, `s` substitute char.
- `p` paste after, `P` before. `yy` yank line.
- `u` undo, `Ctrl-r` redo. `.` repeat last change.
- `J` join line below into current.
- `~` toggle case. `gu`/`gU` lowercase/uppercase motion.

## Counts

- Prefix a count: `3dd` delete 3 lines, `5j` down 5, `2dw` delete 2 words.

## Search & replace

- `/pattern` search forward, `?` backward; `n`/`N` next/prev match.
- `*` search word under cursor.
- `:%s/old/new/g` replace all in file. `:%s/old/new/gc` confirm each.
- `:s/old/new/g` current line only. `:'<,'>s/.../.../g` in visual selection.
- `:noh` clear search highlight.

## Files, buffers, windows, tabs

- `:w` write, `:q` quit, `:wq` or `ZZ` save+quit, `:q!` quit no-save, `:x` write if changed.
- `:e file` edit file. `:bn`/`:bp` next/prev buffer, `:ls` list, `:b name`.
- `:sp`/`:vsp` horizontal/vertical split. `Ctrl-w h/j/k/l` move between windows.
- `Ctrl-w q` close window, `Ctrl-w =` equalize.
- `:tabnew`, `gt`/`gT` next/prev tab.

## Marks, registers, macros

- `m<a>` set mark a, `` `a `` jump to it, `'a` jump to its line.
- `"ayy` yank into register a, `"ap` paste from it. `"+y` yank to system clipboard.
- `qa` record macro into register a, `q` stop, `@a` replay, `@@` replay last.

## Useful settings (~/.vimrc)

- `:set number` / `:set relativenumber` line numbers.
- `:set ignorecase smartcase` case-insensitive unless capital typed.
- `:set hlsearch incsearch` highlight + incremental search.
- `:set expandtab shiftwidth=4 tabstop=4` spaces for tabs.

## Common workflows

- Delete to end of file: `dG`. To start: `dgg`.
- Change everything inside braces block: `ci{`.
- Indent a block in visual mode: select with `V` then `>`.
- Reformat / re-indent whole file: `gg=G`.
- Insert same text on many lines: `Ctrl-v` block, `I` text `Esc`.
- Quit all windows: `:qa` (or `:qa!`).
