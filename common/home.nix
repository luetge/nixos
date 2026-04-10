{
  pkgs,
  user,
  isWorkMachine,
  sops-nix,
  config,
  lib,
  noSystemInstall ? false,
  ...
}:

let
  fontFamily = "M+1Code Nerd Font Mono";
  extra_pkgs = import ../overlays/pkgs.nix { inherit pkgs; };
  claude-wrapper = pkgs.writeShellScriptBin "claude" ''
    export DISABLE_INSTALLATION_CHECKS=1
    if [[ "$PWD" == "$HOME/personal"* ]]; then
      export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
    else
      export CLAUDE_CONFIG_DIR="$HOME/.claude-work"
    fi
    exec ${pkgs.claude-code}/bin/claude "$@"
  '';
  safe-reattach-to-user-namespace =
    if pkgs.stdenv.isDarwin then
      pkgs.reattach-to-user-namespace
    else
      pkgs.writeShellScriptBin "reattach-to-user-namespace" ''
        exec "$@"
      '';
  compress-pdf = pkgs.writeShellScriptBin "compress-pdf" ''
    set -e
    ${pkgs.ghostscript}/bin/gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.7 -dColorConversionStrategy=/sRGB -dNOPAUSE -dQUIET -dBATCH -sOutputFile="$2" "$1"
  '';
  tweag-nickel = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      publisher = "tweag";
      name = "vscode-nickel";
      version = "0.5.0";
      hash = "sha256-FmpjscJ/Iq4bmjmMPZypNd1DbsXkNBLXbImrkW+Y5KY=";
    };
  };
  user-packages = with pkgs; [
    rsync
    stow
    wget
    zstd
    tldr
    pkg-config
    moreutils
    coreutils
    openssh
    ssh-copy-id
    cacert
    openssl
    nixfmt
    nixd
    manix
    rage
    safe-reattach-to-user-namespace
    docker
    _1password-cli
    ruff
    ty
    azure-cli
    signal-export
    pre-commit
    awscli
    gh
    tree
    # jujutsu is configured via programs.jujutsu below

    nickel
    nls

    poetry
    poetryPlugins.poetry-plugin-shell
    uv
    rustup
    nodejs
    samply
    yq
    openmpi.dev
    poethepoet
    claude-wrapper

    (python313.withPackages (ps: with ps; [ python-lsp-server ]))
    nerd-fonts.fira-code
    marimo
    nix-output-monitor
    ffmpeg
    ffmpeg.dev
    nil

    devenv

    # Better cli tools
    eza
    fd
    sd
    tokei
    hyperfine
    grex
    watchexec
    ripgrep
    hdf5.dev
    cmake

    compress-pdf

    # Fonts
    roboto
    roboto-slab
    roboto-mono
  ];
  homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${user}" else "/home/${user}";
  personalFolder = "~/personal/";
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
    LIBRARY_PATH = "${homeDirectory}/.nix-profile/lib";
    CARGO_HOME = "${homeDirectory}/.cargo";
    RUSTUP_HOME = "${homeDirectory}/.rustup";
    # Point jj to config directory so it loads all .toml files (including SOPS secrets)
    JJ_CONFIG = "${homeDirectory}/.config/jj";
  };
in
{
  imports = [ sops-nix.homeManagerModules.sops ];
  nixpkgs.config.allowUnfree = true;
  nix = lib.mkIf noSystemInstall {
    package = pkgs.nix;
    extraOptions = ''
      !include ${config.sops.secrets.nix_tokens.path}
    '';
  };
  home = {
    enableNixpkgsReleaseCheck = false;
    username = user;
    homeDirectory = homeDirectory;
    packages = user-packages;
    stateVersion = "21.05";
    file = {
      ".vimrc".source = ../dotfiles/.vimrc;
      ".config/tmux/tmux.remote.conf".source = ../dotfiles/.tmux.remote.conf;
      ".config/zed/settings.json".source = ../dotfiles/zed.json;
      ".ssh/id_ed25519_work.pub".source = ../dotfiles/ssh-public-keys/id_ed25519_work.pub;
      ".ssh/id_ed25519_work_laptop.pub".source = ../dotfiles/ssh-public-keys/id_ed25519_work_laptop.pub;
      ".ssh/id_ed25519_work_github.pub".source = ../dotfiles/ssh-public-keys/id_ed25519_work_github.pub;
      ".ssh/id_ed25519_personal.pub".source = ../dotfiles/ssh-public-keys/id_ed25519_personal.pub;
      ".ssh/id_ed25519_personal_github.pub".source =
        ../dotfiles/ssh-public-keys/id_ed25519_personal_github.pub;
      ".ssh/id_ed25519_do.pub".source = ../dotfiles/ssh-public-keys/id_ed25519_do.pub;
      ".ssh/id_ed25519_mh.pub".source = ../dotfiles/ssh-public-keys/id_ed25519_mh.pub;
      # Claude Code settings (plugins + MCP servers + hooks)
      ".claude-personal/settings.json".source = ../dotfiles/claude-settings-personal.json;
      ".claude-work/settings.json".source = ../dotfiles/claude-settings-work.json;
      # Claude Code hooks - personal
      ".claude-personal/hooks/memory-prompt-hook.sh" = {
        source = ../dotfiles/claude-hooks/memory-prompt-hook.sh;
        executable = true;
      };
      ".claude-personal/hooks/precompact-hook.sh" = {
        source = ../dotfiles/claude-hooks/precompact-hook.sh;
        executable = true;
      };
      ".claude-personal/hooks/postcompact-hook.sh" = {
        source = ../dotfiles/claude-hooks/postcompact-hook.sh;
        executable = true;
      };
      # Claude Code hooks - work
      ".claude-work/hooks/memory-prompt-hook.sh" = {
        source = ../dotfiles/claude-hooks/memory-prompt-hook.sh;
        executable = true;
      };
      ".claude-work/hooks/precompact-hook.sh" = {
        source = ../dotfiles/claude-hooks/precompact-hook.sh;
        executable = true;
      };
      ".claude-work/hooks/postcompact-hook.sh" = {
        source = ../dotfiles/claude-hooks/postcompact-hook.sh;
        executable = true;
      };
    };
    sessionVariables = sessionVariables;
  };
  fonts.fontconfig.enable = true;

  sops = {
    age.sshKeyPaths = [ "${homeDirectory}/.ssh/id_ed25519_nixos_key" ];
    defaultSopsFile = ../.sops.yaml;
    # Fix: include system PATH for getconf (needed on macOS to find DARWIN_USER_TEMP_DIR)
    environment.PATH = lib.mkForce "/usr/bin:/bin:/usr/sbin:/sbin";
    # Read all files as binary secret files and make them
    # available as config.sops.secrets.`filename`
    secrets =
      let
        secretFiles = builtins.readDir ../secrets;
        # Determine which jj config to use based on machine type
        # Work config includes [[--scope]] conditional for ~/personal/ override
        jjConfigToUse = if isWorkMachine then "jjconfig_work" else "jjconfig_personal";
        jjConfigToSkip = if isWorkMachine then "jjconfig_personal" else "jjconfig_work";
        # Filter out the unused jj config
        filteredFiles = lib.filterAttrs (name: _: name != jjConfigToSkip) secretFiles;
        # Map secrets to appropriate paths
        toSecret = file: _: {
          sopsFile = ../secrets/${file};
          path =
            # Map selected jj config to user.toml (loaded by jj from config dir)
            if file == jjConfigToUse then
              "${homeDirectory}/.config/jj/user.toml"
            else
              "${homeDirectory}/.config/git/${file}";
          format = "binary";
        };
      in
      pkgs.lib.mapAttrs toSecret filteredFiles;
  };

  services.ollama = {
    enable = true;
    # loadModels = [
    #   "qwen2.5-coder-7b"
    # ];
  };

  programs = {
    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        add_newline = false;
        command_timeout = 1000;
        nix_shell.format = "via [$symbol$state]($style) ";
        python.format = "[\${symbol}\${pyenv_prefix}(\${version})]($style) ";
        rust.format = "[$symbol($version)]($style) ";
      };
    };

    kitty = {
      enable = true;
      font = {
        name = fontFamily;
        size = 18;
      };
      themeFile = "MaterialDark";
      settings = {
        enable_audio_bell = false;
        macos_titlebar_color = "background";
        confirm_os_window_close = 0;
      };
    };
    zsh = {
      enable = true;
      initContent =
        (builtins.readFile ../dotfiles/.zshrc) + "\nexport LIBRARY_PATH=${homeDirectory}/.nix-profile/lib";
      sessionVariables = sessionVariables;
      syntaxHighlighting.enable = true;
      history = {
        extended = true;
        ignoreDups = true;
      };
      plugins = [
        {
          # will source zsh-autosuggestions.plugin.zsh
          name = "zsh-autosuggestions";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-autosuggestions";
            rev = "v0.4.0";
            sha256 = "0z6i9wjjklb4lvr7zjhbphibsyx51psv50gm07mbb0kj9058j6kc";
          };
        }
      ];
    };

    home-manager.enable = true;
    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = ''rg --files --no-ignore --hidden --follow --glob "!.git/*"'';
      changeDirWidgetOptions = [ "--preview 'tree -C {} | head -200'" ];
      changeDirWidgetCommand = "fd -t d . $HOME/code $HOME/personal/code $HOME/Documents";
      tmux.enableShellIntegration = true;
    };
    dircolors = {
      enable = true;
      enableZshIntegration = true;
    };
    direnv = {
      enable = true;
      nix-direnv = {
        enable = true;
      };
      config.global.warn_timeout = "1m";
    };
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
      };
    };
    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
        pager = "less -FR";
      };
    };
    htop.enable = true;
    jq.enable = true;
    less.enable = true;

    tmux = {
      enable = true;
      sensibleOnTop = false;
      extraConfig = builtins.readFile ../dotfiles/.tmux.conf;
    };

    vscode =
      let
        extensions = with pkgs.vscode-extensions; [
          usernamehw.errorlens
          ms-python.python
          ms-vscode-remote.remote-ssh
          ms-python.vscode-pylance
          ms-toolsai.jupyter
          ms-toolsai.jupyter-renderers
          tamasfe.even-better-toml
          jnoortheen.nix-ide
          usernamehw.errorlens
          oderwat.indent-rainbow
          mkhl.direnv
          rust-lang.rust-analyzer
          tweag-nickel
          # astral-sh--ty
          charliermarsh.ruff
          humao.rest-client
          extra_pkgs.ms-toolsai--vscode-ai
          extra_pkgs.ms-toolsai--vscode-ai-remote
          matangover.mypy
          gruntfuggly.todo-tree
          github.vscode-pull-request-github
          # github.remotehub
          github.vscode-github-actions
          anthropic.claude-code
          esbenp.prettier-vscode
          ms-python.debugpy
        ];
      in
      {
        enable = true;
        profiles = {
          default = {
            # extensions = extensions;
            userSettings = builtins.fromJSON (builtins.readFile ../dotfiles/vscode.json) // {
              "editor.fontFamily" =
                "'${fontFamily}', 'FiraCode Nerd Font Mono', Consolas, 'Courier New', monospace";
              "remote.SSH.defaultExtensions" = map (
                ext: "${ext.vscodeExtPublisher}.${ext.vscodeExtName}"
              ) extensions;
            };
          };
        };
        mutableExtensionsDir = true;
      };

    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      withNodeJs = false;
      # coc = {
      #   enable = true;
      # };
      extraConfig = builtins.readFile ../dotfiles/.vimrc;
      plugins = with pkgs.vimPlugins; [
        coc-fzf
        fzf-vim
        fugitive
        vim-polyglot
        # coc-nvim
        vim-jsonnet
        vim-hybrid-material
      ];
    };
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        # On macOS, add 1password SSH keys
        "*" = {
          forwardAgent = true;
          compression = true;
          extraOptions =
            if pkgs.stdenv.isDarwin then
              { IdentityAgent = "~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock"; }
            else
              { };
        };
      };
      includes = [ config.sops.secrets.ssh_config.path ];
    };
    jujutsu = {
      enable = true;
      settings = {
        ui = {
          default-command = "log";
          paginate = "never";
        };
      };
    };

    git = {
      package = pkgs.gitFull;
      enable = true;

      includes = [
        {
          path =
            if isWorkMachine then
              config.sops.secrets.gitconfig_work.path
            else
              config.sops.secrets.gitconfig_personal.path;
        }
        {
          condition = "gitdir:${personalFolder}";
          path = config.sops.secrets.gitconfig_personal.path;
        }
      ];

      lfs.enable = true;
      settings = {
        init = {
          defaultBranch = "main";
        };
        apply = {
          whitespace = "fix";
        };
        commit.gpgsign = true;
        push.autoSetupRemote = true;
        gpg.format = "ssh";
        "gpg \"ssh\"".program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
        alias = {
          l = "log --pretty=oneline -n 20 --graph --abbrev-commit";
          l1 = "log --pretty=oneline -n 1";

          # View the current working tree status using the short format
          s = "status -s";

          # Show the diff between the latest commit and the current state
          d = "!git diff-index --quiet HEAD -- || clear; git --no-pager diff --patch-with-stat";

          # Pull in remote changes for the current repository and all its submodules
          p = "!git pull; git submodule update --remote";

          # Commit all changes
          ca = "!git add -A && git commit -av";

          # Switch to a branch, creating it if necessary
          go = ''!f() { git checkout -b "$1" 2> /dev/null || git checkout "$1"; }; f'';
        };

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
        help = {
          autocorrect = "1";
        };
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
