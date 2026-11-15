{
  inputs,
  ...
}:
{
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFeedbackCommands = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      AutofillAddressEnabled = true;
      AutofillCreditCardEnabled = false;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
    };

    profiles.default.search = {
      force = true;
      default = "google";
      engines = {
        google = {
          name = "Google";
          urls = [
            { template = "https://www.google.com/search?q={searchTerms}"; }
          ];
          definedAliases = [ "@g" ];
        };
        ddg = {
          name = "DuckDuckGo";
          urls = [
            { template = "https://duckduckgo.com/?q={searchTerms}"; }
          ];
          definedAliases = [
            "@d"
            "@ddg"
          ];
        };
        wikipedia = {
          name = "Wikipedia";
          urls = [
            { template = "https://en.wikipedia.org/w/index.php?search={searchTerms}"; }
          ];
          definedAliases = [ "@w" ];
        };
        youtube = {
          name = "YouTube";
          urls = [
            { template = "https://www.youtube.com/results?search_query={searchTerms}"; }
          ];
          definedAliases = [ "@yt" ];
        };
        github = {
          name = "GitHub";
          urls = [
            { template = "https://github.com/search?q={searchTerms}"; }
          ];
          definedAliases = [ "@gh" ];
        };

        flathub = {
          name = "Flathub";
          urls = [
            { template = "https://flathub.org/apps/search?q={searchTerms}"; }
          ];
          definedAliases = [
            "@flathub"
            "@flat"
          ];
        };
        nixpkgs = {
          name = "Nix Packages";
          urls = [
            { template = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}"; }
          ];
          definedAliases = [
            "@nix"
            "@np"
          ];
        };
        nixoptions = {
          name = "NixOS Options";
          urls = [
            { template = "https://search.nixos.org/options?channel=unstable&query={searchTerms}"; }
          ];
          definedAliases = [
            "@no"
            "@nopt"
          ];
        };
        mynixos = {
          name = "MyNixOS";
          urls = [
            { template = "https://mynixos.com/search?q={searchTerms}"; }
          ];
          definedAliases = [ "@myn" ];
        };
        home-manager = {
          name = "Home Manager Options";
          urls = [
            { template = "https://home-manager-options.extranix.com/?query={searchTerms}"; }
          ];
          definedAliases = [
            "@hm"
            "@hmo"
          ];
        };
        debian = {
          name = "Debian Packages (apt)";
          urls = [
            { template = "https://packages.debian.org/search?keywords={searchTerms}"; }
          ];
          definedAliases = [
            "@apt"
            "@deb"
            "@debian"
          ];
        };
        ubuntu = {
          name = "Ubuntu Packages";
          urls = [
            { template = "https://packages.ubuntu.com/search?keywords={searchTerms}"; }
          ];
          definedAliases = [
            "@ubuntu"
            "@upkg"
          ];
        };
        arch = {
          name = "Arch Linux Packages";
          urls = [
            { template = "https://archlinux.org/packages/?q={searchTerms}"; }
          ];
          definedAliases = [
            "@arch"
            "@pacman"
          ];
        };
        aur = {
          name = "Arch User Repository";
          urls = [
            { template = "https://aur.archlinux.org/packages?K={searchTerms}"; }
          ];
          definedAliases = [
            "@aur"
            "@yay"
          ];
        };
        archwiki = {
          name = "Arch Wiki";
          urls = [
            { template = "https://wiki.archlinux.org/index.php?search={searchTerms}"; }
          ];
          definedAliases = [
            "@awiki"
            "@wiki"
          ];
        };
        fedora = {
          name = "Fedora Packages";
          urls = [
            { template = "https://packages.fedoraproject.org/search?query={searchTerms}"; }
          ];
          definedAliases = [ "@fedora" ];
        };
        opensuse = {
          name = "openSUSE Software";
          urls = [
            { template = "https://software.opensuse.org/search?q={searchTerms}"; }
          ];
          definedAliases = [
            "@suse"
            "@opensuse"
          ];
        };
        gentoo = {
          name = "Gentoo Packages";
          urls = [
            { template = "https://packages.gentoo.org/packages/search?q={searchTerms}"; }
          ];
          definedAliases = [ "@gentoo" ];
        };
        snap = {
          name = "Snapcraft";
          urls = [
            { template = "https://snapcraft.io/search?q={searchTerms}"; }
          ];
          definedAliases = [ "@snap" ];
        };
        crates = {
          name = "crates.io";
          urls = [
            { template = "https://crates.io/search?q={searchTerms}"; }
          ];
          definedAliases = [
            "@crates"
            "@cargo"
          ];
        };
        npm = {
          name = "npm";
          urls = [
            { template = "https://www.npmjs.com/search?q={searchTerms}"; }
          ];
          definedAliases = [
            "@npm"
            "@node"
          ];
        };
        pypi = {
          name = "PyPI";
          urls = [
            { template = "https://pypi.org/search/?q={searchTerms}"; }
          ];
          definedAliases = [
            "@pypi"
            "@pip"
          ];
        };
        docker = {
          name = "Docker Hub";
          urls = [
            { template = "https://hub.docker.com/search?q={searchTerms}"; }
          ];
          definedAliases = [
            "@docker"
            "@hub"
          ];
        };

        amazon = {
          name = "Amazon";
          urls = [
            { template = "https://www.amazon.com/s?k={searchTerms}"; }
          ];
          definedAliases = [ "@a" ];
        };
        reddit = {
          name = "Reddit";
          urls = [
            { template = "https://www.reddit.com/search/?q={searchTerms}"; }
          ];
          definedAliases = [ "@r" ];
        };
        stackoverflow = {
          name = "Stack Overflow";
          urls = [
            { template = "https://stackoverflow.com/search?q={searchTerms}"; }
          ];
          definedAliases = [
            "@so"
            "@stack"
          ];
        };
        hackernews = {
          name = "Hacker News";
          urls = [
            { template = "https://hn.algolia.com/?q={searchTerms}"; }
          ];
          definedAliases = [
            "@hn"
            "@news"
          ];
        };
      };
    };
  };
}
