#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
dependencies=$(mktemp -d "${TMPDIR:-/tmp}/gearpass-deps.XXXXXXXX")
tar -xzf dependencies.tar.gz -C "$dependencies"
export PYTHONPATH="$dependencies${PYTHONPATH:+:$PYTHONPATH}"
exec python -m uvicorn main:app --host 0.0.0.0 --port "${PORT:-8000}"
