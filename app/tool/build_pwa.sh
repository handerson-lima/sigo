#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --no-web-resources-cdn --pwa-strategy=none "$@"
python3 tool/prepare_pwa.py
