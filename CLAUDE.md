# Repo: nix-darwin + home-manager config for Daniel's machines

## Layout

- `flake.nix` — inputs (nixpkgs 26.05-darwin + unstable), `darwinConfigurations.dlutgehet-work-macbook`, standalone `homeConfigurations.dlutgehet` (for non-managed/remote machines), helper scripts as packages.
- `common/base.nix` — nix-darwin module shared across machines (nix settings, linux-builder, home-manager wiring). Defines the `local.isWorkMachine` option.
- `common/home.nix` — home-manager config (packages, programs, sops secrets, dotfile symlinks).
- `machines/macbook_work/` — machine config + `brew.nix` (GUI apps/casks; nix handles CLI).
- `dotfiles/` — live-symlinked into `$HOME` **out of the store** (see below).
- `secrets/` — sops-encrypted (age key derived from an SSH key stored in 1Password).
- `scripts.nix` — `install`, `edit-secrets`, `rotate-secrets`, `setup-ssh`, `create-age-key`.

## Key conventions

- **Dotfiles are live symlinks**: editing `dotfiles/*` (zshrc, tmux.conf, vimrc, claude settings/hooks, zed/vscode json) takes effect immediately, **no rebuild needed**. A rebuild is only needed for `*.nix` changes or when adding/removing a symlink in `common/home.nix`.
- **Machine config uses the module system**: add options via `imports`, never `//` attrset merging.
- **Project build deps (hdf5, boost, cmake, …) do NOT go in `common/home.nix`** — they belong in per-project dev shells (direnv + nix-direnv/devenv are set up globally).
- Claude Code configs are split: `~/.claude-personal` for `~/personal/*`, `~/.claude-work` elsewhere (see the `claude` wrapper in `common/home.nix`).

## Commands

- Rebuild system: `system-update` (prefers the local checkout at `~/personal/nixos`) or `sudo darwin-rebuild switch --flake .#dlutgehet-work-macbook`
- Build without switching (verification): `nix build .#darwinConfigurations.dlutgehet-work-macbook.system`
- Format: `nix fmt` (nixfmt via treefmt; also enforced by pre-commit)
- Check: `nix flake check`
- Edit a secret: `nix run .#edit-secrets -- secrets/<file>`
- After changing `.sops.yaml` keys: `nix run .#rotate-secrets`
