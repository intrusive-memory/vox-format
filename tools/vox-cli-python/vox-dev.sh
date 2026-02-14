#!/usr/bin/env bash
# Development wrapper script for vox CLI
# Usage: ./vox-dev.sh inspect examples/minimal/narrator.vox

cd "$(dirname "$0")/../.." || exit 1

python3.14 -c "
import sys
sys.path.insert(0, 'tools/vox-cli-python/src')
sys.path.insert(0, 'implementations/python/src')
from vox_cli.cli import cli
cli()
" "$@"
