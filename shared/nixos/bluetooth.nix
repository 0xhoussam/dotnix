{ ... }:
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
    settings.General = {
      # Battery levels of headsets/earbuds (BlueZ battery provider) for the bar.
      Experimental = true;
      # Quicker reconnects to known devices (slightly more power while on).
      FastConnectable = true;
    };
  };
}
