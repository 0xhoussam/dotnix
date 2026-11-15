{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.claude-code;

  claudeCodeTools = [
    pkgs.bun
    pkgs.gh
    pkgs.nodejs_latest
    pkgs.rtk
    pkgs.python314Packages.firecrawl-py
  ];

  exports = lib.mapAttrsToList (
    name: value: "export ${name}=${lib.escapeShellArg value}"
  ) cfg.extraEnv;

  claudeWrapper = pkgs.writeShellScriptBin "claude" ''
    ${lib.concatStringsSep "\n" exports}
    exec ${pkgs.claude-code}/bin/claude "$@"
  '';

  claude = if cfg.extraEnv == { } then pkgs.claude-code else claudeWrapper;
in
{
  options.custom.claude-code = {
    enable = lib.mkEnableOption "Claude Code" // {
      default = true;
    };
    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Static environment variables exported by the `claude` wrapper; with none set, plain pkgs.claude-code is installed.";
    };
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
    };
    extraGitIgnores = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    extraShellAliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Fish abbreviations for Claude Code.";
    };
  };

  config = {
    nixpkgs.overlays = [
      inputs.claude-code.overlays.default
      (final: prev: {
        claude-code = prev.symlinkJoin {
          name = "claude-code-${prev.claude-code.version or "wrapped"}";
          paths = [ prev.claude-code ];
          nativeBuildInputs = [ prev.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/claude \
              --prefix PATH : ${prev.lib.makeBinPath [ prev.nodejs ]}
          '';
          inherit (prev.claude-code) meta;
        };
      })
    ];

    home = lib.mkIf cfg.enable {
      sessionVariables.CLAUDE_BINARY = "${pkgs.claude-code}/bin/.claude-unwrapped";
      packages = [ claude ] ++ claudeCodeTools ++ cfg.extraPackages;
    };

    programs = lib.mkIf cfg.enable {
      git.ignores = cfg.extraGitIgnores;
      fish.shellAbbrs = cfg.extraShellAliases;
    };
  };
}
