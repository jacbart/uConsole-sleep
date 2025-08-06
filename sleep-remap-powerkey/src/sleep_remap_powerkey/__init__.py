import fcntl
import os
import select
import struct
import threading
from time import time

# Try to import uinput, but don't fail if it's not available (e.g., on macOS)
try:
    import uinput
    UINPUT_AVAILABLE = True
except ImportError:
    UINPUT_AVAILABLE = False
    print("Warning: uinput module not available (this is expected on macOS)")

from .find_power_key import find_power_key
from .sleep_display_control import toggle_display

KEY_POWER = 116
HOLD_TRIGGER_SEC = float(os.environ.get("HOLD_TRIGGER_SEC") or 0.7)


def timer_input_power_task(device):
    if UINPUT_AVAILABLE:
        device.emit(uinput.KEY_POWER, 1)
        device.emit(uinput.KEY_POWER, 0)
    else:
        print("Warning: uinput not available, skipping power key emission")


def main():
    """Main entry point for the sleep-remap-powerkey script."""
    if not UINPUT_AVAILABLE:
        print("Error: uinput module not available. This script requires Linux.")
        return
    
    EVENT_DEVICE = find_power_key()
    
    with open(EVENT_DEVICE, "rb") as f:
        fcntl.ioctl(f, 0x40044590, 1)

        epoll = select.epoll()
        epoll.register(f.fileno(), select.EPOLLIN)

        uinput_device = uinput.Device([uinput.KEY_POWER])

        try:
            last_key_down_timestamp = 0
            input_power_timer = None

            while True:
                events = epoll.poll()
                current_time = time()
                for fileno, event in events:
                    if fileno == f.fileno():
                        event_data = f.read(24)
                        if not event_data:
                            break

                        sec, usec, event_type, code, value = struct.unpack("qqHHi", event_data)

                        if event_type == 1 and code == KEY_POWER:
                            if value == 1:
                                print("SRP: power key down input detected.")
                                last_key_down_timestamp = current_time
                                input_power_timer = threading.Timer(HOLD_TRIGGER_SEC, timer_input_power_task, args=(uinput_device,))
                                input_power_timer.start()
                            else:
                                print("SRP: power key up input detected.")
                                if input_power_timer != None and (current_time - last_key_down_timestamp) < HOLD_TRIGGER_SEC:
                                    input_power_timer.cancel()
                                    toggle_display()

        finally:
            epoll.unregister(f.fileno())
            epoll.close()


if __name__ == "__main__":
    main()
