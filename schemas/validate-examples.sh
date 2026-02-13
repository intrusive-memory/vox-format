#!/usr/bin/env bash
#
# validate-examples.sh - Validate all VOX example manifests against the JSON Schema
#
# Usage: bash schemas/validate-examples.sh
#
# Requires: Python 3 with jsonschema module installed
#   Install: pip install jsonschema
#
# This script:
#   1. Validates standalone manifest.json files directly
#   2. Extracts manifest.json from .vox (ZIP) archives and validates them
#   3. Runs negative tests against intentionally invalid manifests
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEMA="$SCRIPT_DIR/manifest-v0.1.0.json"

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  NC='\033[0m'
else
  GREEN=''
  RED=''
  YELLOW=''
  NC=''
fi

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

validate_manifest() {
  local manifest_path="$1"
  local label="$2"
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  if python3 -c "
import json, sys
try:
    import jsonschema
except ImportError:
    print('ERROR: jsonschema module not installed. Run: pip install jsonschema', file=sys.stderr)
    sys.exit(2)

with open('$SCHEMA') as f:
    schema = json.load(f)
with open('$manifest_path') as f:
    data = json.load(f)
try:
    jsonschema.validate(data, schema)
    sys.exit(0)
except jsonschema.ValidationError as e:
    print(f'  Error: {e.message}', file=sys.stderr)
    path = '.'.join(str(p) for p in e.absolute_path)
    if path:
        print(f'  Path: {path}', file=sys.stderr)
    sys.exit(1)
" 2>&1; then
    echo -e "  ${GREEN}PASS${NC}: $label"
    PASS_COUNT=$((PASS_COUNT + 1))
    return 0
  else
    echo -e "  ${RED}FAIL${NC}: $label"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 1
  fi
}

validate_vox_file() {
  local vox_path="$1"
  local label="$2"
  local tmpdir

  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" RETURN

  if ! unzip -q "$vox_path" -d "$tmpdir" 2>/dev/null; then
    echo -e "  ${RED}FAIL${NC}: $label (not a valid ZIP archive)"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 1
  fi

  if [ ! -f "$tmpdir/manifest.json" ]; then
    echo -e "  ${RED}FAIL${NC}: $label (no manifest.json in archive)"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 1
  fi

  validate_manifest "$tmpdir/manifest.json" "$label"
}

validate_invalid_manifest() {
  local manifest_path="$1"
  local label="$2"
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  if python3 -c "
import json, sys
try:
    import jsonschema
except ImportError:
    print('ERROR: jsonschema module not installed. Run: pip install jsonschema', file=sys.stderr)
    sys.exit(2)

with open('$SCHEMA') as f:
    schema = json.load(f)
with open('$manifest_path') as f:
    data = json.load(f)
try:
    jsonschema.validate(data, schema)
    sys.exit(0)
except jsonschema.ValidationError as e:
    print(f'{e.message}')
    sys.exit(1)
" 2>&1; then
    echo -e "  ${RED}FAIL${NC}: $label (expected rejection, but it passed)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 1
  else
    echo -e "  ${GREEN}PASS${NC}: $label (correctly rejected)"
    PASS_COUNT=$((PASS_COUNT + 1))
    return 0
  fi
}

# ---- Main ----

echo ""
echo "VOX Schema Validation"
echo "====================="
echo "Schema: $SCHEMA"
echo ""

# Verify schema file exists
if [ ! -f "$SCHEMA" ]; then
  echo -e "${RED}ERROR${NC}: Schema file not found: $SCHEMA"
  exit 1
fi

# --- Positive tests: standalone manifest files ---
echo "--- Validating standalone manifests ---"

validate_manifest "$PROJECT_DIR/examples/minimal/manifest.json" \
  "examples/minimal/manifest.json"

validate_manifest "$PROJECT_DIR/examples/character/narrator-with-context-manifest.json" \
  "examples/character/narrator-with-context-manifest.json"

validate_manifest "$PROJECT_DIR/examples/multi-engine/manifest.json" \
  "examples/multi-engine/manifest.json"

echo ""

# --- Positive tests: .vox archives ---
echo "--- Validating .vox archives ---"

validate_vox_file "$PROJECT_DIR/examples/minimal/narrator.vox" \
  "examples/minimal/narrator.vox"

validate_vox_file "$PROJECT_DIR/examples/character/narrator-with-context.vox" \
  "examples/character/narrator-with-context.vox"

validate_vox_file "$PROJECT_DIR/examples/multi-engine/cross-platform.vox" \
  "examples/multi-engine/cross-platform.vox"

echo ""

# --- Negative tests: invalid manifests ---
echo "--- Validating negative tests (should all be rejected) ---"

if [ -d "$SCRIPT_DIR/test" ]; then
  for invalid_file in "$SCRIPT_DIR"/test/invalid-*.json; do
    if [ -f "$invalid_file" ]; then
      basename=$(basename "$invalid_file")
      validate_invalid_manifest "$invalid_file" "test/$basename"
    fi
  done
else
  echo -e "  ${YELLOW}SKIP${NC}: No test/ directory found"
fi

echo ""

# --- Summary ---
echo "====================="
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo -e "${GREEN}All examples valid${NC} ($PASS_COUNT/$TOTAL_COUNT tests passed)"
  exit 0
else
  echo -e "${RED}$FAIL_COUNT/$TOTAL_COUNT tests failed${NC}"
  exit 1
fi
