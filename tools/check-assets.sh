#!/usr/bin/env bash
# Verify assets/ still matches the committed assets.sha256.
# Exits non-zero if they drifted (used by the pre-commit hook and CI).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
py="$(command -v python3 || command -v python || command -v py || true)"
[ -n "$py" ] || { echo "error: Python 3.8+ is required" >&2; exit 1; }
exec "$py" "$here/assets.py" --root "$repo" check "$@"
