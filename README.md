# nix-based config for macOS & RaspberryPi

## Requirements for installation on macOS

* Username matching username in nix recipe
* Installed 1password with CLI extension enabled
* Installed nix
* SSH key for secret encryption in 1password under name "nix encryption SSH Key" (not generated through 1password but through `ssh-keygen -t ed25519 -C "username@email.com"`)

## Installation (as system)

`nix run github:luetge/nixos`

## Installation of home manager (on non-managed systems)
`nix run github:nix-community/home-manager -- switch --flake "git+ssh://git@github.com/luetge/nixos.git"`

## Update (after installation)

`system-update`

## Dotfiles (live symlinks)

Dotfiles in `./dotfiles/` are **not** copied into the read-only `/nix/store`.
Instead they are symlinked out of the store directly into a live checkout of
this repo, expected at `~/personal/nixos`. Editing a dotfile there (e.g.
`~/personal/nixos/dotfiles/.zshrc`) takes effect immediately — no rebuild
needed. `.zshrc`, `.tmux.conf` and `.vimrc` are sourced live from the checkout
as well, with graceful fallbacks if the checkout is missing.

This means you should clone the repo to `~/personal/nixos`:

```
git clone git@github.com:luetge/nixos.git ~/personal/nixos
```

See https://matklad.github.io/2026/05/21/symlinking-nixos-dotfiles.html for the
rationale. A rebuild (`system-update`) is only needed when you change `*.nix`
files or add/remove a dotfile from the symlink list in `common/home.nix`.

## Commands

* Install on current machine: `nix run` or `nix run .#install`
* Add to/edit the encrypted secrets (which are contained in `./secrets/`): `nix run .#edit-secrets ./secrets/your_filename_here`
* Format: `nix run .#fmt-srcs`
* Run git-hooks: `nix run .#git-hooks`

## TODO

* Make it work to install from branches
