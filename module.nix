{ ... }:
{
  systemd.services."sleep-remap-powerkey" = {
    description = "Sleep Remap PowerKey";
    after = [ "basic.target" ];
    serviceConfig = {
      User = "root";
      Group = "root";
      EnvironmentFile = "/etc/uconsole-sleep/config";
      ExecStartPre = "/sbin/modprobe uinput";
      ExecStart = "/usr/local/bin/sleep_remap_powerkey";
      Restart = "always";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    wantedBy = [ "basic.target" ];
  };

  systemd.services."sleep-power-control" = {
    description = "Sleep Power Control Based on Display and Sleep State";
    after = [ "basic.target" ];
    serviceConfig = {
      User = "root";
      Group = "root";
      EnvironmentFile = "/etc/uconsole-sleep/config";
      ExecStart = "/usr/local/bin/sleep_power_control";
      Restart = "always";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    wantedBy = [ "basic.target" ];
  };
}
