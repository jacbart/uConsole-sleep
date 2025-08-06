#!/usr/bin/env python3
"""Setup script for sleep-remap-powerkey package."""

from setuptools import setup, find_packages

setup(
    name="sleep-remap-powerkey",
    version="0.1.0",
    description="Sleep remap powerkey for uConsole",
    author="jacbart",
    author_email="jacbart@gmail.com",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    install_requires=[
        "python-uinput>=0.11.2",
    ],
    entry_points={
        "console_scripts": [
            "sleep-remap-powerkey=sleep_remap_powerkey:main",
        ],
    },
    python_requires=">=3.12",
) 