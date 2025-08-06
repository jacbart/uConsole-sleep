#!/usr/bin/env python3
"""Test script to verify package imports work correctly."""

import sys
import os

def test_sleep_power_control():
    """Test importing sleep-power-control package."""
    try:
        # Set environment variables to avoid errors
        os.environ["DISABLE_POWER_OFF_KB"] = "yes"
        os.environ["DISABLE_CPU_MIN_FREQ"] = "yes"
        
        # Import the module but don't execute the main logic
        import sleep_power_control
        print("✓ sleep-power-control module imported successfully")
        return True
    except Exception as e:
        print(f"✗ sleep-power-control import failed: {e}")
        return False

def test_sleep_remap_powerkey():
    """Test importing sleep-remap-powerkey package."""
    try:
        # Import the module but don't execute the main logic
        import sleep_remap_powerkey
        print("✓ sleep-remap-powerkey module imported successfully")
        return True
    except Exception as e:
        print(f"✗ sleep-remap-powerkey import failed: {e}")
        return False

if __name__ == "__main__":
    print("Testing package imports...")
    
    success = True
    success &= test_sleep_power_control()
    success &= test_sleep_remap_powerkey()
    
    if success:
        print("\n✓ All packages imported successfully!")
        sys.exit(0)
    else:
        print("\n✗ Some packages failed to import.")
        sys.exit(1) 