{
  description = "uConsole Sleep flake using uv2nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      uv2nix,
      pyproject-nix,
      pyproject-build-systems,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      # Load a uv workspace from a workspace root.
      # Uv2nix treats all uv projects as workspace projects.
      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

      # Create package overlay from workspace.
      overlay = workspace.mkPyprojectOverlay {
        # Prefer prebuilt binary wheels as a package source.
        # Sdists are less likely to "just work" because of the metadata missing from uv.lock.
        # Binary wheels are more likely to, but may still require overrides for library dependencies.
        sourcePreference = "wheel"; # or sourcePreference = "sdist";
        # Optionally customise PEP 508 environment
        # environ = {
        #   platform_release = "5.10.65";
        # };
      };

      # Extend generated overlay with build fixups
      #
      # Uv2nix can only work with what it has, and uv.lock is missing essential metadata to perform some builds.
      # This is an additional overlay implementing build fixups.
      # See:
      # - https://pyproject-nix.github.io/uv2nix/FAQ.html
      pyprojectOverrides = _final: _prev: {
        # Implement build fixups here.
        # Note that uv2nix is _not_ using Nixpkgs buildPythonPackage.
        # It's using https://pyproject-nix.github.io/pyproject.nix/build.html
      };

      # Support multiple architectures
      supportedSystems = [ "aarch64-linux" "aarch64-darwin" "x86_64-linux" "x86_64-darwin" ];

      # Create package set for each supported system
      forAllSystems = lib.genAttrs supportedSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          python = pkgs.python312; # Use Python 3.12 for better compatibility

          # Construct package set
          pythonSet =
            # Use base package set from pyproject.nix builders
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
              (
                lib.composeManyExtensions [
                  pyproject-build-systems.overlays.default
                  overlay
                  pyprojectOverrides
                ]
              );
        in
        {
          inherit pkgs python pythonSet;
        }
      );

    in
    {
      # Expose the workspace for debugging
      workspace = workspace;

      # Package virtual environments for each app
      packages = lib.genAttrs supportedSystems (system:
        let
          pythonSet = forAllSystems.${system}.pythonSet;
        in
        {
          # Default package is the sleep-power-control environment
          default = pythonSet.mkVirtualEnv "sleep-power-control-env" workspace.deps.all;
          
          # Individual app environments
          sleep-power-control = pythonSet.mkVirtualEnv "sleep-power-control-env" workspace.deps.all;
          sleep-remap-powerkey = pythonSet.mkVirtualEnv "sleep-remap-powerkey-env" workspace.deps.all;
        }
      );

      # Make apps runnable with `nix run`
      apps = lib.genAttrs supportedSystems (system:
        let
          pkgs = forAllSystems.${system}.pkgs;
        in
        {
          # Default app is sleep-power-control
          default = {
            type = "app";
            program = "${self.packages.${system}."sleep-power-control"}/bin/sleep-power-control";
          };
          
          sleep-power-control = {
            type = "app";
            program = "${self.packages.${system}."sleep-power-control"}/bin/sleep-power-control";
          };
          
          sleep-remap-powerkey = {
            type = "app";
            program = "${self.packages.${system}."sleep-remap-powerkey"}/bin/sleep-remap-powerkey";
          };
        }
      );

      # NixOS modules for systemd services (only for Linux)
      nixosModules = lib.genAttrs [ "aarch64-linux" "x86_64-linux" ] (system:
        {
          default = { config, pkgs, lib, ... }: {
            imports = [ ./module.nix ];
            _module.args = {
              sleep-power-control = self.packages.${system}."sleep-power-control";
              sleep-remap-powerkey = self.packages.${system}."sleep-remap-powerkey";
            };
          };
          uconsole-sleep = { config, pkgs, lib, ... }: {
            imports = [ ./module.nix ];
            _module.args = {
              sleep-power-control = self.packages.${system}."sleep-power-control";
              sleep-remap-powerkey = self.packages.${system}."sleep-remap-powerkey";
            };
          };
        }
      );

      # VM checks for cross-compilation and testing (only for Linux)
      checks = lib.genAttrs [ "aarch64-linux" "x86_64-linux" ] (system:
        let
          pkgs = forAllSystems.${system}.pkgs;
        in
        {
          testVm = pkgs.testers.runNixOSTest {
            name = "uconsole-sleep-tests";

            nodes.machine = {
              config,
              pkgs,
              lib,
              ...
            }: {
              # Basic system configuration
              networking.useDHCP = true;
              networking.hostName = "uconsole-test";
              
              # Enable required kernel modules for testing
              boot.kernelModules = [ "uinput" "evdev" ];
              
              # Add our packages to the system
              environment.systemPackages = [
                self.packages.${system}."sleep-power-control"
                self.packages.${system}."sleep-remap-powerkey"
              ];
              
              # Import our module for testing
              imports = [ ./module.nix ];
              
              # Create test configuration directory
              system.activationScripts.testConfig = ''
                mkdir -p /etc/uconsole-sleep
                cat > /etc/uconsole-sleep/config << 'EOF'
                # Test configuration
                SAVING_CPU_FREQ=0.6,1.2
                DISABLE_POWER_OFF_KB=no
                DISABLE_CPU_MIN_FREQ=no
                DISABLE_POWER_OFF_DRM=no
                HOLD_TRIGGER_SEC=0.7
                EOF
              '';
              
              # Create mock hardware for testing
              system.activationScripts.mockHardware = ''
                # Create mock backlight device
                mkdir -p /sys/class/backlight/backlight@0
                echo "4" > /sys/class/backlight/backlight@0/bl_power
                echo "100" > /sys/class/backlight/backlight@0/brightness
                echo "100" > /sys/class/backlight/backlight@0/max_brightness
                
                # Create mock CPU frequency controls
                mkdir -p /sys/devices/system/cpu/cpufreq/policy0
                echo "600000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
                echo "1200000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
                echo "600000" > /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_min_freq
                echo "1200000" > /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq
                
                # Create mock USB keyboard device
                mkdir -p /sys/bus/usb/devices/1-1
                echo "1-1" > /sys/bus/usb/devices/1-1/uevent
                mkdir -p /sys/bus/usb/devices/1-1/power
                echo "auto" > /sys/bus/usb/devices/1-1/power/control
                echo "0" > /sys/bus/usb/devices/1-1/power/autosuspend_delay_ms
                
                # Create mock USB driver
                mkdir -p /sys/bus/usb/drivers/usb
                
                # Create mock power key event device
                mkdir -p /dev/input
                mknod /dev/input/event0 c 13 64
                chmod 666 /dev/input/event0
              '';
              
              # Enable services for testing
              services.sleep-power-control.enable = true;
              services.sleep-remap-powerkey.enable = true;
            };

            testScript = ''
              # Wait for system to boot
              machine.wait_for_unit("default.target")
              
              # Test 1: Verify packages are available
              machine.succeed("which sleep-power-control")
              machine.succeed("which sleep-remap-powerkey")
              
              # Test 2: Verify configuration files
              machine.succeed("test -f /etc/uconsole-sleep/config")
              machine.succeed("grep -q 'SAVING_CPU_FREQ=0.6,1.2' /etc/uconsole-sleep/config")
              
              # Test 3: Verify mock hardware setup
              machine.succeed("test -f /sys/class/backlight/backlight@0/bl_power")
              machine.succeed("test -f /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq")
              machine.succeed("test -c /dev/input/event0")
              
              # Test 4: Start services and verify they're running
              machine.wait_for_unit("sleep-power-control.service")
              machine.wait_for_unit("sleep-remap-powerkey.service")
              
              # Test 5: Test sleep-power-control functionality
              initial_freq = machine.succeed("cat /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq").strip()
              
              # Simulate screen off (bl_power = 4)
              machine.succeed("echo '4' > /sys/class/backlight/backlight@0/bl_power")
              machine.sleep(2)
              
              # Check if CPU frequency was reduced
              new_freq = machine.succeed("cat /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq").strip()
              assert new_freq != initial_freq, f"CPU frequency should change, got {new_freq} vs {initial_freq}"
              
              # Simulate screen on (bl_power = 0)
              machine.succeed("echo '0' > /sys/class/backlight/backlight@0/bl_power")
              machine.sleep(2)
              
              # Check if CPU frequency was restored
              restored_freq = machine.succeed("cat /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq").strip()
              assert restored_freq == initial_freq, f"CPU frequency should be restored, got {restored_freq} vs {initial_freq}"
              
              # Test 6: Verify services are still running after functionality test
              machine.succeed("systemctl is-active sleep-power-control.service")
              machine.succeed("systemctl is-active sleep-remap-powerkey.service")
              
              print("All tests passed successfully!")
            '';
          };
        }
      );

      # This example provides two different modes of development:
      # - Impurely using uv to manage virtual environments
      # - Pure development using uv2nix to manage virtual environments
      devShells = lib.genAttrs supportedSystems (system:
        let
          pkgs = forAllSystems.${system}.pkgs;
          python = forAllSystems.${system}.python;
          pythonSet = forAllSystems.${system}.pythonSet;
        in
        {
          # It is of course perfectly OK to keep using an impure virtualenv workflow and only use uv2nix to build packages.
          # This devShell simply adds Python and undoes the dependency leakage done by Nixpkgs Python infrastructure.
          impure = pkgs.mkShell {
            packages = [
              python
              pkgs.uv
            ];
            env = {
              # Prevent uv from managing Python downloads
              UV_PYTHON_DOWNLOADS = "never";
              # Force uv to use nixpkgs Python interpreter
              UV_PYTHON = python.interpreter;
            }
            // lib.optionalAttrs pkgs.stdenv.isLinux {
              # Python libraries often load native shared objects using dlopen(3).
              # Setting LD_LIBRARY_PATH makes the dynamic library loader aware of libraries without using RPATH for lookup.
              LD_LIBRARY_PATH = lib.makeLibraryPath pkgs.pythonManylinuxPackages.manylinux1;
            };
            shellHook = ''
              unset PYTHONPATH
            '';
          };

          # This devShell uses uv2nix to construct a virtual environment purely from Nix, using the same dependency specification as the application.
          # The notable difference is that we also apply another overlay here enabling editable mode ( https://setuptools.pypa.io/en/latest/userguide/development_mode.html ).
          #
          # This means that any changes done to your local files do not require a rebuild.
          #
          # Note: Editable package support is still unstable and subject to change.
          uv2nix =
            let
              # Create an overlay enabling editable mode for all local dependencies.
              editableOverlay = workspace.mkEditablePyprojectOverlay {
                # Use environment variable
                root = "$REPO_ROOT";
                # Optional: Only enable editable for these packages
                members = [ "sleep-power-control" "sleep-remap-powerkey" ];
              };

              # Override previous set with our overrideable overlay.
              editablePythonSet = pythonSet.overrideScope (
                lib.composeManyExtensions [
                  editableOverlay

                  # Apply fixups for building an editable package of your workspace packages
                  (final: prev: {
                    sleep-power-control = prev.sleep-power-control.overrideAttrs (old: {
                      # It's a good idea to filter the sources going into an editable build
                      # so the editable package doesn't have to be rebuilt on every change.
                      src = lib.fileset.toSource {
                        root = old.src;
                        fileset = lib.fileset.unions [
                          (old.src + "/pyproject.toml")
                          (old.src + "/README.md")
                          (old.src + "/src/sleep_power_control/__init__.py")
                          (old.src + "/src/sleep_power_control/find_backlight.py")
                          (old.src + "/src/sleep_power_control/find_internal_kb.py")
                        ];
                      };

                      # Hatchling (our build system) has a dependency on the `editables` package when building editables.
                      #
                      # In normal Python flows this dependency is dynamically handled, and doesn't need to be explicitly declared.
                      # This behaviour is documented in PEP-660.
                      #
                      # With Nix the dependency needs to be explicitly declared.
                      nativeBuildInputs =
                        old.nativeBuildInputs
                        ++ final.resolveBuildSystem {
                          editables = [ ];
                        };
                    });

                    sleep-remap-powerkey = prev.sleep-remap-powerkey.overrideAttrs (old: {
                      # It's a good idea to filter the sources going into an editable build
                      # so the editable package doesn't have to be rebuilt on every change.
                      src = lib.fileset.toSource {
                        root = old.src;
                        fileset = lib.fileset.unions [
                          (old.src + "/pyproject.toml")
                          (old.src + "/README.md")
                          (old.src + "/src/sleep_remap_powerkey/__init__.py")
                          (old.src + "/src/sleep_remap_powerkey/find_backlight.py")
                          (old.src + "/src/sleep_remap_powerkey/find_drm_panel.py")
                          (old.src + "/src/sleep_remap_powerkey/find_framebuffer.py")
                          (old.src + "/src/sleep_remap_powerkey/find_power_key.py")
                          (old.src + "/src/sleep_remap_powerkey/sleep_display_control.py")
                        ];
                      };

                      # Hatchling (our build system) has a dependency on the `editables` package when building editables.
                      #
                      # In normal Python flows this dependency is dynamically handled, and doesn't need to be explicitly declared.
                      # This behaviour is documented in PEP-660.
                      #
                      # With Nix the dependency needs to be explicitly declared.
                      nativeBuildInputs =
                        old.nativeBuildInputs
                        ++ final.resolveBuildSystem {
                          editables = [ ];
                        };
                    });
                  })
                ]
              );
            in
            pkgs.mkShell {
              packages = [
                pkgs.uv
              ];

              env = {
                # Don't create venv using uv
                UV_NO_SYNC = "1";

                # Force uv to use nixpkgs Python interpreter
                UV_PYTHON = python.interpreter;

                # Prevent uv from downloading managed Python's
                UV_PYTHON_DOWNLOADS = "never";
              };

              shellHook = ''
                # Undo dependency propagation by nixpkgs.
                unset PYTHONPATH

                # Get repository root using git. This is expanded at runtime by the editable `.pth` machinery.
                export REPO_ROOT=$(git rev-parse --show-toplevel)
              '';
            };
        }
      );
    };
}
