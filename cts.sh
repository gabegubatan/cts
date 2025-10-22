#!/usr/bin/env bash
# Usage: ./check_shasum.sh <file> <expected_checksum>
# If checksum mismatches, prompt to (K)eep / (Q)uarantine / (D)elete / (P)rint path

FILE="$1"
EXPECTED="$2"

# Config: quarantine dir (you can change)
QUARANTINE_DIR="$HOME/.local/quarantine"
LOGFILE="/tmp/checksum_quarantine.log"

# helpers
err() { printf "ERROR: %s\n" "$*" >&2; }
info() { printf "%s\n" "$*"; }

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
CALCULATED=$(shasum -a 256 -- "$FILE" | awk '{print $1}')

# match?
if [ "$CALCULATED" = "$EXPECTED" ]; then
  info "✅ Checksum matches: $CALCULATED"
  exit 0
fi

# mismatch: warn and present options
info "❌ Checksum does NOT match!"
info "Expected: $EXPECTED"
info "Found:    $CALCULATED"
info ""

# If non-interactive (no tty), default to quarantine
if [ ! -t 0 ]; then
  info "No interactive TTY detected. Defaulting to quarantine."
  ACTION="q"
else
  # interactive prompt loop
  while true; do
    printf "Choose action — (K)eep / (Q)uarantine / (D)elete / (P)rint path: "
    read -r CHOICE
    # normalize
    CHOICE=$(printf "%s" "$CHOICE" | tr '[:upper:]' '[:lower:]')
    case "$CHOICE" in
      k|keep)
        ACTION="k"
        break
        ;;
      q|quarantine)
        ACTION="q"
        break
        ;;
      d|delete)
        ACTION="d"
        break
        ;;
      p|print|path)
        ACTION="p"
        break
        ;;
      *)
        printf "Invalid choice — try again.\n"
        ;;
    esac
  done
fi

# Do action
timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
case "$ACTION" in
  k)
    info "Leaving file alone for further analysis: $FILE"
    echo "$(date -u) KEEP    $FILE expected:$EXPECTED found:$CALCULATED" >> "$LOGFILE"
    exit 0
    ;;
  q)
    # ensure quarantine dir exists
    mkdir -p -- "$QUARANTINE_DIR" || { err "Could not create $QUARANTINE_DIR"; exit 5; }

    base=$(basename -- "$FILE")
    target="$QUARANTINE_DIR/${base}_${timestamp}"
    # move file to quarantine
    mv -- "$FILE" "$target" || { err "Failed to move file to quarantine"; exit 6; }
    info "File quarantined to: $target"
    echo "$(date -u) QUARANTINE $FILE -> $target expected:$EXPECTED found:$CALCULATED" >> "$LOGFILE"
    exit 0
    ;;
  d)
    # confirm destructive action
    if [ -t 0 ]; then
      printf "Are you sure you want to permanently DELETE '%s'? Type DELETE to confirm: " "$FILE"
      read -r CONF
      if [ "$CONF" != "DELETE" ]; then
        info "Delete cancelled."
        exit 1
      fi
    else
      # non-interactive, do not delete
      err "Non-interactive environment: refusing to delete. Use quarantine."
      exit 7
    fi

    # attempt to securely remove if shred available, else rm
    if command -v shred >/dev/null 2>&1; then
      shred -u -- "$FILE" || { err "shred failed; attempting rm"; rm -f -- "$FILE"; }
    else
      rm -f -- "$FILE"
    fi
    info "File deleted: $FILE"
    echo "$(date -u) DELETE    $FILE expected:$EXPECTED found:$CALCULATED" >> "$LOGFILE"
    exit 0
    ;;
  p)
    info "File path: $FILE"
    echo "$(date -u) PRINTPATH $FILE expected:$EXPECTED found:$CALCULATED" >> "$LOGFILE"
    exit 0
    ;;
  *)
    err "Unknown action. Exiting."
    exit 8
    ;;
esac

