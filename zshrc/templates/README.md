# README

Project starter templates. Not sourced by the shell loader; consumed by `tpl` (see `aliases/utils/tpl`) and `jsnew` (in `aliases/utils/external`).

Each `_<name>/` directory is one template. The leading underscore is kept as a visual marker (and from prior layout, where templates lived under `aliases/utils/` and were skipped by the loader's `grep -v "/_"`).

Path is exported as `$ZSH_CUSTOM_CONFIG_TEMPLATES` from `routes`.
