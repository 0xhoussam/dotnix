{ ... }:
{
  programs.firefox.profiles."pride" = {
    name = "pride";
    isDefault = true;
    id = 0;

    settings = {
      toolkit.legacyUserProfileCustomizations.stylesheets = true;
    };

    search.force = true;
    search.default = "DuckDuckGo";

    userChrome = # css
      ''
        /* Source file https://github.com/MrOtherGuy/firefox-csshacks/tree/master/chrome/hide_tabs_toolbar.css made available under Mozilla Public License v. 2.0
        See the above repository for updates as well as full license text. */

        /* Hides tabs toolbar */
        /* For OSX use hide_tabs_toolbar_osx.css instead */

        /* Note, if you have either native titlebar or menubar enabled, then you don't really need this style.
         * In those cases you can just use: #TabsToolbar{ visibility: collapse !important }
         */

        /* IMPORTANT */
        /*
        Get window_control_placeholder_support.css
        Window controls will be all wrong without it
        */

        :root[tabsintitlebar]{ --uc-toolbar-height: 40px; }
        :root[tabsintitlebar][uidensity="compact"]{ --uc-toolbar-height: 32px }
        #titlebar{
          will-change: unset !important;
          transition: none !important;
          opacity: 1 !important;
        }
        #TabsToolbar{ visibility: collapse !important }
        :root[sizemode="fullscreen"] #titlebar{ position: relative }

        :root[sizemode="fullscreen"] #TabsToolbar > .titlebar-buttonbox-container{
          visibility: visible !important;
          z-index: 2;
        }

        :root:not([inFullscreen]) #nav-bar{
          margin-top: calc(0px - var(--uc-toolbar-height,0px));
        }

        :root[tabsintitlebar] #toolbar-menubar[autohide="true"]{
          min-height: unset !important;
          height: var(--uc-toolbar-height,0px) !important;
          position: relative;
        }

        #toolbar-menubar[autohide="false"]{
          margin-bottom: var(--uc-toolbar-height,0px)
        }

        :root[tabsintitlebar] #toolbar-menubar[autohide="true"] #main-menubar{
          flex-grow: 1;
          align-items: stretch;
          background-attachment: scroll, fixed, fixed;
          background-position: 0 0, var(--lwt-background-alignment), right top;
          background-repeat: repeat-x, var(--lwt-background-tiling), no-repeat;
          background-size: auto 100%, var(--lwt-background-size, auto auto), auto auto;
          padding-right: 20px;
        }
        :root[tabsintitlebar] #toolbar-menubar[autohide="true"]:not([inactive]) #main-menubar{
          background-color: var(--lwt-accent-color);
          background-image: linear-gradient(var(--toolbar-bgcolor,--toolbar-non-lwt-bgcolor),var(--toolbar-bgcolor,--toolbar-non-lwt-bgcolor)), var(--lwt-additional-images,none), var(--lwt-header-image, none);
          mask-image: linear-gradient(to left, transparent, black 20px);
        }

        #toolbar-menubar:not([inactive]){ z-index: 2 }
        #toolbar-menubar[autohide="true"][inactive] > #menubar-items {
          opacity: 0;
          pointer-events: none;
          margin-left: var(--uc-window-drag-space-pre,0px)
        }


        #urlbar:not([focused]) #urlbar-input, /* ID for Firefox 70 */
        #urlbar:not([focused]) .urlbar-input{ text-align: center !important; }

      '';
  };

  programs.firefox = {
    policies = {
      BlockAboutConfig = false;
      DefaultDownloadDirectory = "\${home}/Downloads";
      AutofillCreditCardEnabled = false;
      AutofillAddressEnabled = false;
      DisableAccounts = true;
      DisableAppUpdate = true;
      DisableFeedbackCommands = true;
      DisableFirefoxAccounts = true;
      DisableFirefoxStudies = true;
      DisableFormHistory = true;
      DisplayBookmarksToolbar = false;
      DisableMasterPasswordCreation = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;
      EnableTrackingProtection = {
        Value = true;
        Fingerprinting = true;
        Cryptomining = true;
        Locked = true;
      };
      NetworkPrediction = true;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
      PostQuantumKeyAgreementEnabled = true;
      TranslateEnabled = true;
      FirefoxHome = {
        Search = false;
        TopSites = false;
        SponsoredTopSites = false;
        Highlights = false;
        Pocket = false;
        SponsoredPocket = false;
        Snippets = false;
        Locked = true;
      };
      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = "https://cloudflare-dns.com/dns-query";
        Locked = true;
        ExcludedDomains = [ "example.com" ];
        Fallback = true;
      };
      Permissions = {
        Notifications = {
          BlockNewRequests = true;
          Locked = true;
        };
      };
      ShowHomeButton = false;
      StartDownloadsInTempDirectory = true;
    };
  };
}
