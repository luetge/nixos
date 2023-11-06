{ pkgs, user, isWorkMachine, sops-nix, config, lib, noSystemInstall ? false, ...
}:

let
  safe-reattach-to-user-namespace = if pkgs.stdenv.isDarwin then
    pkgs.reattach-to-user-namespace
  else
    pkgs.writeShellScriptBin "reattach-to-user-namespace" ''
      exec "$@"
    '';
  user-packages = with pkgs; [
    rsync
    stow
    wget
    zstd
    tldr
    pkg-config
    inetutils
    moreutils
    ack
    coreutils
    libiconv
    findutils
    openssh
    xz
    ssh-copy-id
    cacert
    openssl
    pcre2
    gettext
    nixfmt
    rnix-lsp
    nil
    manix
    rage
    safe-reattach-to-user-namespace
    docker
    _1password
    ruff

    poetry

    # Better cli tools
    bat
    eza
    fd
    sd
    tokei
    hyperfine
    grex
    watchexec
    ripgrep

    # Fonts
    roboto
    roboto-slab
    roboto-mono
  ];
  homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${user}" else "/home/${user}";
  personalFolder = "~/personal/";
in {
  imports = [ sops-nix.homeManagerModules.sops ];
  nixpkgs.config.allowUnfree = true;
  nix = {
    package = lib.mkIf noSystemInstall pkgs.nix;
    extraOptions = ''
      !include ${config.sops.secrets.nix_tokens.path}
    '';
  };
  home = {
    username = user;
    homeDirectory = homeDirectory;
    packages = user-packages;
    stateVersion = "21.05";
    file = {
      ".config/tmux/tmux.remote.conf".source = ../dotfiles/.tmux.remote.conf;
      ".bash_profile".source = ../dotfiles/.bash_profile;
      ".ssh/id_ed25519_work.pub".source =
        ../dotfiles/ssh-public-keys/id_ed25519_work.pub;
      ".ssh/id_ed25519_personal.pub".source =
        ../dotfiles/ssh-public-keys/id_ed25519_personal.pub;
    };
    sessionVariables = {
      HISTSIZE = "5000";
      SAVEHIST = "5000";
      EDITOR = "vim";
      LESSCHARSET = "utf-8";
      PAGER = "less -R";
      TERM = "xterm-256color";
      CLICOLOR = "1";
      LC_ALL = "en_US.UTF-8";
      LANG = "en_US.UTF-8";
    };
  };
  fonts.fontconfig.enable = true;

  sops = {
    age.sshKeyPaths = [ "${homeDirectory}/.ssh/id_ed25519_nixos_key" ];
    defaultSopsFile = ../.sops.yaml;
    # Read all files as binary secret files and make them
    # available as config.sops.secrets.`filename`
    secrets = let
      toSecret = file: _: {
        sopsFile = ../secrets/${file};
        path = "${homeDirectory}/.config/git/${file}";
        format = "binary";
      };
    in pkgs.lib.mapAttrs toSecret (builtins.readDir ../secrets);
  };

  programs = {
    starship = {
      enable = true;
      enableZshIntegration = true;
    };

    kitty = {
      enable = true;
      font = {
        name = "FiraCode Nerd Font Mono Regular";
        size = 18;
      };
      theme = "Material Dark";
      settings = {
        enable_audio_bell = false;
        macos_titlebar_color = "background";
        confirm_os_window_close = 0;
      };
    };
    zsh = {
      enable = true;
      initExtra = builtins.readFile ../dotfiles/.zshrc;
      syntaxHighlighting.enable = true;
      history = {
        extended = true;
        ignoreDups = true;
      };
      plugins = [{
        # will source zsh-autosuggestions.plugin.zsh
        name = "zsh-autosuggestions";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-autosuggestions";
          rev = "v0.4.0";
          sha256 = "0z6i9wjjklb4lvr7zjhbphibsyx51psv50gm07mbb0kj9058j6kc";
        };
      }];
    };

    home-manager.enable = true;
    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand =
        ''rg --files --no-ignore --hidden --follow --glob "!.git/*"'';
      changeDirWidgetOptions = [ "--preview 'tree -C {} | head -200'" ];
      changeDirWidgetCommand =
        "fd -t d . $HOME/code $HOME/personal/code $HOME/Documents";
      tmux.enableShellIntegration = true;
    };
    dircolors = {
      enable = true;
      enableZshIntegration = true;
    };
    direnv = {
      enable = true;
      nix-direnv = { enable = true; };
    };
    htop.enable = true;
    jq.enable = true;
    less.enable = true;

    tmux = {
      enable = true;
      extraConfig = builtins.readFile ../dotfiles/.tmux.conf;
    };

    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        usernamehw.errorlens
        ms-python.python
        ms-vscode-remote.remote-ssh
        ms-python.vscode-pylance
        tamasfe.even-better-toml
        jnoortheen.nix-ide
        usernamehw.errorlens
        oderwat.indent-rainbow
        mkhl.direnv
        rust-lang.rust-analyzer
        esbenp.prettier-vscode
        charliermarsh.ruff
      ];
      userSettings =
        builtins.fromJSON (builtins.readFile ../dotfiles/vscode.json);
    };

    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      withNodeJs = false;
      coc = { enable = true; };
      extraConfig = builtins.readFile ../dotfiles/.vimrc;
      plugins = with pkgs.vimPlugins; [
        coc-fzf
        fzf-vim
        fugitive
        vim-polyglot
        coc-nvim
        vim-jsonnet
        vim-hybrid-material
      ];
    };
    ssh = {
      enable = true;
      compression = true;
      forwardAgent = true;
      matchBlocks = {
        # On macOS, add 1password SSH keys
        "*" = {
          extraOptions = if pkgs.stdenv.isDarwin then {
            IdentityAgent =
              "~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock";
          } else
            { };
        };
      };
    };
    git = {
      package = pkgs.gitAndTools.gitFull;
      enable = true;

      includes = [
        {
          path = if isWorkMachine then
            config.sops.secrets.gitconfig_work.path
          else
            config.sops.secrets.gitconfig_personal.path;
        }
        {
          condition = "gitdir:${personalFolder}";
          path = config.sops.secrets.gitconfig_personal.path;
        }
      ];

      aliases = {
        l = "log --pretty=oneline -n 20 --graph --abbrev-commit";
        l1 = "log --pretty=oneline -n 1";

        # View the current working tree status using the short format
        s = "status -s";

        # Show the diff between the latest commit and the current state
        d =
          "!git diff-index --quiet HEAD -- || clear; git --no-pager diff --patch-with-stat";

        # Pull in remote changes for the current repository and all its submodules
        p = "!git pull; git submodule update --remote";

        # Commit all changes
        ca = "!git add -A && git commit -av";

        # Switch to a branch, creating it if necessary
        go = ''
          !f() { git checkout -b "$1" 2> /dev/null || git checkout "$1"; }; f'';

      };
      lfs.enable = true;
      extraConfig = {
        init = { defaultBranch = "main"; };
        apply = { whitespace = "fix"; };
        commit.gpgsign = true;
        gpg.format = "ssh";
        "gpg \"ssh\"".program =
          "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";

        core = {
          # Use custom `.gitignore` and `.gitattributes`
          excludesfile = "~/.gitignore";
          attributesfile = "~/.gitattributes";

          # Treat spaces before tabs and all kinds of trailing whitespace as an error
          # [default] trailing-space: looks for spaces at the end of a line
          # [default] space-before-tab: looks for spaces before tabs at the beginning of a line
          whitespace = "space-before-tab,-indent-with-non-tab,trailing-space";

          # Make `git rebase` safer on OS X
          # More info: <http://www.git-tower.com/blog/make-git-rebase-safe-on-osx/>
          trustctime = "false";

          # Prevent showing files whose names contain non-ASCII symbols as unversioned.
          # http://michael-kuehnel.de/git/2014/11/21/git-mac-osx-and-german-umlaute.html
          precomposeunicode = "false";

          # Special vim mode to alter the vimrc loading behavior, i.e. no long loading plugins
          editor = "GIT=1 vim";
          ignorecase = "true";
        };
        color = {
          # Use colors in Git commands that are capable of colored output when
          # outputting to the terminal. (This is the default setting in Git ≥ 1.8.4.)
          ui = "auto";
        };
        "color \"branch\"" = {
          current = "yellow reverse";
          local = "yellow";
          remote = "green";
        };
        "color \"diff\"" = {
          meta = "yellow bold";
          frag = "magenta bold";
          old = "red";
          new = "green";
        };
        "color \"status\"" = {
          added = "yellow";
          changed = "green";
          untracked = "cyan";
        };
        diff = {
          # Detect copies as well as renames
          renames = "copies";
        };
        help = { autocorrect = "1"; };
        merge = {
          # Include summaries of merged commits in newly created merge commit messages
          log = "true";
        };
        push = {
          default = "matching";
          followTags = "true";
        };
        pull = {
          rebase = "true";
          ff = "only";
        };
      };
    };
  };
}
