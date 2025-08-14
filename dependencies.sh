#!/usr/bin/env bash
set -e

echo "[TUXD] Installing dependencies for Debian/Ubuntu..."

sudo apt update
sudo apt install -y \
    build-essential \
    pkg-config \
    git \
    curl

echo "[TUXD] Done. You can now build with: cargo build"

