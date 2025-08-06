#!/usr/bin/env python3
"""Setup script for sleep-power-control package."""

from setuptools import setup, find_packages

setup(
    name="sleep-power-control",
    version="0.1.0",
    description="Sleep power control for uConsole",
    author="jacbart",
    author_email="jacbart@gmail.com",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    install_requires=[
        "inotify-simple>=1.3.5",
    ],
    entry_points={
        "console_scripts": [
            "sleep-power-control=sleep_power_control:main",
        ],
    },
    python_requires=">=3.12",
) 