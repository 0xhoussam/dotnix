{
  inputs,
  pkgs,
  ...
}:
{
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

  home.packages = [ pkgs.claude-code ];
}
