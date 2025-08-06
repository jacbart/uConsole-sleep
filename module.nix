{ lib, config, sleep-power-control, sleep-remap-powerkey, ... }:
{
  options = {
    services.sleep-power-control.enable = lib.mkEnableOption "Enable sleep-power-control service";
    services.sleep-remap-powerkey.enable = lib.mkEnableOption "Enable sleep-remap-powerkey service";
  };

  config = lib.mkMerge [
    (lib.mkIf (config.services.sleep-power-control.enable || config.services.sleep-remap-powerkey.enable) {
      # Create configuration directory and file
      environment.etc."uconsole-sleep/config".text = ''
        ###########################################################################
        #                    uConsole-Sleep configuration file                    #
        ###########################################################################

        ### HOLD_TRIGGER_SEC --- [0.0~] --- Time(sec) to trigger power interactive
        # default 0.7
        #HOLD_TRIGGER_SEC=1.3

        ### SAVING_CPU_FREQ --- [100,100~] <min,max> --- Freq(MHz) for power saving
        # default 100,100 (depends on cpuinfo)
        #SAVING_CPU_FREQ=300,600

        ### DISABLE_POWER_OFF_DRM --- [yes/no] --- Disable turn off DRM on sleep
        ###  - If you have some issue with recover screen, you can set this "yes"
        # default no
        #DISABLE_POWER_OFF_DRM=yes

        ### DISABLE_POWER_OFF_KB --- [yes/no] --- Disable turn off Keyboard on sleep
        ###  - If you set this to "yes", the keyboard can turn on/off the light.
        # default no
        #DISABLE_POWER_OFF_KB=yes

        ### DISABLE_CPU_MIN_FREQ --- [yes/no] --- Disable set cpu freq max to min
        # default no
        #DISABLE_CPU_MIN_FREQ=yes
      '';
    })

    (lib.mkIf config.services.sleep-power-control.enable {
      systemd.services."sleep-power-control" = {
        description = "Sleep Power Control Based on Display and Sleep State";
        after = [ "basic.target" ];
        serviceConfig = {
          User = "root";
          Group = "root";
          EnvironmentFile = "/etc/uconsole-sleep/config";
          ExecStart = "${sleep-power-control}/bin/sleep-power-control";
          Restart = "always";
          StandardOutput = "journal";
          StandardError = "journal";
        };
        wantedBy = [ "basic.target" ];
      };
    })

    (lib.mkIf config.services.sleep-remap-powerkey.enable {
      systemd.services."sleep-remap-powerkey" = {
        description = "Sleep Remap PowerKey";
        after = [ "basic.target" ];
        serviceConfig = {
          User = "root";
          Group = "root";
          EnvironmentFile = "/etc/uconsole-sleep/config";
          ExecStartPre = "/sbin/modprobe uinput";
          ExecStart = "${sleep-remap-powerkey}/bin/sleep-remap-powerkey";
          Restart = "always";
          StandardOutput = "journal";
          StandardError = "journal";
        };
        wantedBy = [ "basic.target" ];
      };
    })
  ];
}
