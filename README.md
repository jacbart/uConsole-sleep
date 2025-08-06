# uConsole Sleep Workspace

This workspace contains two Python applications for managing sleep and power states on uConsole devices, built with modern Nix tooling using uv2nix.

## Applications

### sleep-power-control
Monitors display state and controls power management based on screen status. It can:
- Monitor backlight power state
- Control CPU frequency scaling
- Manage USB keyboard power states
- Respond to display on/off events

### sleep-remap-powerkey
Remaps the power key to control display sleep/wake instead of system sleep. It can:
- Monitor power key events
- Toggle display on/off with short press
- Trigger system sleep with long press
- Control framebuffer and DRM panel states

## Development

### Using uv (impure development)
```bash
# Enter development shell
nix develop .#impure

# Install dependencies
uv sync

# Run applications
uv run sleep-power-control
uv run sleep-remap-powerkey
```

### Using uv2nix (pure development)
```bash
# Enter development shell
nix develop .#uv2nix

# Run applications
sleep-power-control
sleep-remap-powerkey
```

## Building and Running

### Build packages
```bash
# Build all packages
nix build

# Build specific package
nix build .#sleep-power-control
nix build .#sleep-remap-powerkey
```

### Run applications
```bash
# Run default app (sleep-power-control)
nix run

# Run specific app
nix run .#sleep-power-control
nix run .#sleep-remap-powerkey
```

## Testing

### VM Testing
The workspace includes VM tests that verify the Python scripts work correctly:

```bash
# Run VM tests
nix flake check

# Run specific test
nix build .#checks.aarch64-linux.testVm
```

The VM tests verify:
- Package installation and availability
- Service startup and configuration
- CPU frequency scaling functionality
- Display state monitoring
- Basic functionality of both applications

### Interactive Testing
```bash
# Start interactive test session
nix build .#checks.aarch64-linux.testVm
./result/bin/nixos-test-driver --interactive
```

## Installation

### Using NixOS module from flake
Add to your `configuration.nix`:
```nix
# Import the flake
inputs.uconsole-sleep.url = "github:your-username/uConsole-sleep";

# In your configuration
imports = [ inputs.uconsole-sleep.nixosModules.default ];

# Enable services
services.sleep-power-control.enable = true;
services.sleep-remap-powerkey.enable = true;
```

### Using NixOS module directly
Add to your `configuration.nix`:
```nix
imports = [ ./module.nix ];

# Enable services
services.sleep-power-control.enable = true;
services.sleep-remap-powerkey.enable = true;
```

### Manual installation
```bash
# Install to system
nix profile install .#sleep-power-control
nix profile install .#sleep-remap-powerkey
```

## Configuration

The configuration file is automatically installed at `/etc/uconsole-sleep/config` when you enable the services. You can customize the settings by editing this file:

```bash
# Available configuration options:
# HOLD_TRIGGER_SEC=0.7          # Time(sec) to trigger power interactive
# SAVING_CPU_FREQ=300,600       # Freq(MHz) for power saving <min,max>
# DISABLE_POWER_OFF_DRM=yes     # Disable turn off DRM on sleep
# DISABLE_POWER_OFF_KB=yes      # Disable turn off Keyboard on sleep
# DISABLE_CPU_MIN_FREQ=yes      # Disable set cpu freq max to min
```

### Example Configuration
```bash
# Enable power saving with custom CPU frequency
SAVING_CPU_FREQ=300,600

# Disable keyboard power management (keeps keyboard lights on)
DISABLE_POWER_OFF_KB=yes

# Custom power key hold time
HOLD_TRIGGER_SEC=1.0
```

## Architecture Support

This workspace supports:
- aarch64-linux (uConsole with Raspberry Pi CM4/CM5)

## Dependencies

- Python 3.13+
- inotify-simple (for sleep-power-control)
- python-uinput (for sleep-remap-powerkey)
- Linux kernel modules: uinput, evdev

## Project Structure

```
uConsole-sleep/
├── flake.nix                 # Main flake with VM tests
├── module.nix                # NixOS module for services
├── sleep-power-control/      # Power control service
├── sleep-remap-powerkey/     # Power key remapping service
└── README.md                # This file
```

## About

This is a NixOS-compatible version of the original [uConsole-sleep](https://github.com/qkdxorjs1002/uConsole-sleep) project, built with modern Python tooling (uv2nix) and comprehensive VM testing.

The original project provides two background processes:
- **sleep-remap-powerkey**: Detects power key events and controls screen power
- **sleep-power-control**: Manages power-saving operations based on screen status

This NixOS version maintains the same functionality while providing:
- Reproducible builds with uv2nix
- Comprehensive VM testing
- Easy deployment via NixOS modules
- Optimized for uConsole with Raspberry Pi CM4/CM5
