{}:

let
    commonEnvs = builtins.fetchGit {
        url = "https://github.com/avanov/nix-common.git";
        ref = "master";
        rev = "be2dc05bf6beac92fc12da9a2adae6994c9f2ee6";
    };
    ghcEnv  = import "${commonEnvs}/ghc-env.nix"
                {   haskellLibraries = pkgSet: with pkgSet; [
                        haskell-language-server
                        stylish-haskell
                        cabal-install
                        cabal2nix
                    ];

                };
    pkgs    = ghcEnv.pkgs;

    macOsDeps = with pkgs; lib.optionals stdenv.isDarwin [
        darwin.apple_sdk.frameworks.CoreServices
        darwin.apple_sdk.frameworks.ApplicationServices
    ];

    devEnv  = pkgs.mkShellNoCC {
        # Sets the build inputs, i.e. what will be available in our
        # local environment.
        nativeBuildInputs = with pkgs; [
            cachix
            cacert
            glibcLocales
            gnumake
            gitAndTools.pre-commit
            postgresql
            ghcEnv.ghc
            zlib
        ] ++ macOsDeps;
        shellHook = ''
            export PROJECT_PLATFORM="${builtins.currentSystem}"
            export LANG=en_GB.UTF-8

            # https://cabal.readthedocs.io/en/3.4/installing-packages.html#environment-variables
            export CABAL_DIR=$PWD/.local/${builtins.currentSystem}/cabal

            # symbolic link to Language Server to satisfy VSCode Haskell plugins
            ln -s -f `which haskell-language-server` $PWD/hls.exe
        '';
    };

in

{
    inherit devEnv;
}
