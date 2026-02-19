# chdman-macos-installer

A fully automated, bulletproof shell script to install **chdman** globally on macOS systems, supporting both **Intel (x86_64)** and **Apple Silicon (arm64)** architectures.

This script is designed to be:

- **Idempotent**: safe to re-run multiple times without breaking your setup
- **Verbose**: prints clear progress messages for every step
- **Cross-arch compatible**: automatically detects architecture and sets Homebrew prefixes
- **User-friendly**: provides informative logging with colors for info, success, warnings, and errors

## Features

- Automatically installs **Homebrew** if missing
- Updates Homebrew and ensures `rom-tools` is installed/upgraded
- Links `chdman` globally in your PATH (`/usr/local/bin` or `/opt/homebrew/bin`)
- Verifies installation and reports version

## Usage

```bash
chmod +x install_chdman.sh
./install_chdman.sh
