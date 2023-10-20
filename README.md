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

## Commands

* Install on current machine: `nix run` or `nix run .#install`
* Add to/edit the encrypted secrets (which are contained in `./secrets/`): `nix run .#edit-secrets ./secrets/your_filename_here`
* Format: `nix run .#fmt-srcs`
* Run git-hooks: `nix run .#git-hooks`

## TODO

* Make it work to install from branches
