# install.sh

macOS setup automation script.

## Structure
- `install.sh` - Main zsh script (not bash)
- `Brewfile` - Homebrew packages
- `settings` - macOS defaults commands (eval'd line-by-line)
- `dock` - Dock layout config (op + arg per line)

## Validation
- `zsh -n install.sh` - Syntax check (ignore sandbox `nice(5)` warning)

## Conventions
- Sections use `confirm()` helper for Y/n or y/N prompts
- Brewfile entries are alphabetically sorted
- **All sections MUST be idempotent** — running the script multiple times must be safe and produce the same result. Guard file appends with `grep -qF`, check for existing installs before installing, etc.
