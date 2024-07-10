{
  description = "My version of the Pento app specified in *Programming Phoenix LiveView* by Bruce Tate and Sophie DeBenedetto.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-parts.url = "github:hercules-ci/flake-parts";

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.pre-commit-hooks.flakeModule
      ];

      systems = ["x86_64-linux" "aarch64-linux"];
      perSystem = {
        config,
        system,
        ...
      }: let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        beamDeps = builtins.attrValues (import ./deps.nix {inherit (pkgs) lib beamPackages;});
      in rec {
        devShells.default = let
          # Most of this postgres devShell config was taken from
          # https://zeroes.dev/p/nix-recipe-for-postgresql/
          postgresConf =
            pkgs.writeText "postgresql.conf"
            ''
              log_min_messages = warning
              log_min_error_statement = error
              log_min_duration_statement = 100 # ms
              log_connections = on
              log_disconnections = on
              log_duration = on
              #log_line_prefix = '[] '
              log_timezone = 'UTC'
              log_statement = 'all'
              log_directory = 'pg_log'
              log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
              logging_collector = on
              log_min_error_statement = error
            '';
        in
          pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              elixir
              mix2nix
              postgresql
              inotify-tools
            ];

            # TODO: I don't like this bodge but I've spent almost two hours
            # trying to just run a postgres server locally in the devShell and
            # this is the only way I've found that works
            PGDATA = "/home/dyson/repos/pento/.postgres-dev";

            # TODO: Why does pg_ctl refuse to background (but only when using direnv)?
            shellHook = ''
              ${config.pre-commit.installationScript}

              export PGHOST="$PGDATA"
              if [ ! -d $PGDATA ]; then
                pg_ctl initdb -o "-U postgres"
                cat ${postgresConf} >> $PGDATA/postgresql.conf
              fi

              pg_ctl -o "-k $PGDATA" start
            '';
          };

        packages = {
          compile = pkgs.beamPackages.buildMix {
            name = "compile";
            version = "0.1.0";
            src = self;

            inherit beamDeps;
          };

          compile-release = pkgs.beamPackages.buildMix {
            name = "compile-release";
            version = "0.1.0";
            src = self;

            inherit beamDeps;

            buildPhase = "mix release";
          };

          doc = pkgs.beamPackages.buildMix {
            name = "doc";
            version = "0.1.0";
            src = self;

            inherit beamDeps;
            mixEnv = "dev";

            postBuild = "mix docs --no-deps-check";
            postInstall = ''
              mkdir -p $out/share/doc
              cp -rv ./doc/* $out/share/doc/
            '';
          };
        };

        checks =
          packages
          // {
            credo = pkgs.beamPackages.buildMix {
              name = "credo";
              version = "0.1.0";
              src = self;

              inherit beamDeps;

              doCheck = true;
              checkPhase = "mix credo";
            };

            dialyzer = pkgs.beamPackages.buildMix {
              name = "dialyzer";
              version = "0.1.0";
              src = self;

              inherit beamDeps;
              mixEnv = "dev";

              doCheck = true;
              checkPhase = "mix dialyzer";
            };

            format = pkgs.beamPackages.buildMix {
              name = "format";
              version = "0.1.0";
              src = self;

              inherit beamDeps;

              doCheck = true;
              checkPhase = "mix format --check-formatted";
            };

            test = pkgs.beamPackages.buildMix {
              name = "test";
              version = "0.1.0";
              src = self;

              inherit beamDeps;
              mixEnv = "test";

              # Doc tests require `module_info(:compile)` to contain `:source`,
              # but deterministic builds strip the source
              erlangDeterministicBuilds = false;

              doCheck = true;
              checkPhase = "mix test --no-deps-check";
            };
          };

        # See https://flake.parts/options/pre-commit-hooks-nix and
        # https://github.com/cachix/git-hooks.nix/blob/master/modules/hooks.nix
        # for all the available hooks and options
        pre-commit = {
          check.enable = true;

          settings.hooks = {
            check-added-large-files.enable = true;
            check-merge-conflicts.enable = true;
            check-toml.enable = true;
            check-vcs-permalinks.enable = true;
            check-yaml.enable = true;
            end-of-file-fixer.enable = true;
            trim-trailing-whitespace.enable = true;

            alejandra.enable = true;
            statix.enable = true;

            # credo.enable = true;
            mix-format.enable = true;

            dialyzer = {
              enable = true;
              stages = ["pre-push"];
            };
          };
        };
      };
    };
}
