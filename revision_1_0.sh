#!/usr/bin/env bash
# check_shasum_auto.sh
# Usage: ./check_shasum_auto.sh <file> <expected_checksum>
# If checksum mismatches, automatically quarantine the file
# Logs all actions with timestamp
# Optional: color-coded terminal output

FILE="$1"
EXPECTED="$2"

# Config
QUARANTINE_DIR="$HOME/.local/quarantine"
LOGFILE="$HOME/.local/share/checksum_quarantine.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# helpers
err() { printf "${RED}ERROR:${NC} %s\n" "$*" >&2; }
info() { printf "%s\n" "$*"; }
warn() { printf "${YELLOW}WARNING:${NC} %s\n" "$*"; }
success() { printf "${GREEN}%s${NC}\n" "$*"; }

# sanity checks
if [ -z "$FILE" ] || [ -z "$EXPECTED" ]; then
  err "Usage: $0 <file> <expected_checksum>"
  exit 2
fi

if [ ! -e "$FILE" ]; then
  err "File not found: $FILE"
  exit 3
fi

if [ -d "$FILE" ]; then
  err "Path is a directory, not a file: $FILE"
  exit 4
fi

# calculate sha256
if command -v shasum >/dev/null 2>&1; then
  CALCULATED=$(shasum -a 256 -- "$FILE" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
  CALCULATED=$(sha256sum -- "$FILE" | awk '{print $1}')
else
  err "Neither shasum nor sha256sum found"
  exit 5
fi

# match?
if [ "$CALCULATED" = "$EXPECTED" ]; then
  success "✅ Checksum matches: $CALCULATED"
  echo "$(date -u +"%Y%m%dT%H%M%SZ") KEEP    $FILE expected:$EXPECTED found:$CALCULATED" >> "$LOGFILE"
  exit 0
fi

# mismatch
warn "❌ Checksum does NOT match!"
warn "Expected: $EXPECTED"
warn "Found:    $CALCULATED"

# Automatic quarantine
mkdir -p -- "$QUARANTINE_DIR" || { err "Could not create $QUARANTINE_DIR"; exit 6; }
timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
base=$(basename -- "$FILE")
target="$QUARANTINE_DIR/${base}_${timestamp}"

mv -- "$FILE" "$target" || { err "Failed to move file to quarantine"; exit 7; }

info "File quarantined to: $target"
echo "$(date -u +"%Y%m%dT%H%M%SZ") QUARANTINE $FILE -> $target expected:$EXPECTED found:$CALCULATED" >> "$LOGFILE"

exit 0