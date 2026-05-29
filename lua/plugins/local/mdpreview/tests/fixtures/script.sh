#!/usr/bin/env bash
# script.sh — bash syntax highlight fixture (S3.2, S5.2)

set -euo pipefail

GREET="${1:-world}"

greet() {
  local name="$1"
  echo "Hello, ${name}!"
}

for i in {1..3}; do
  greet "${GREET} (${i})"
done

# Array and associative array
declare -A COLORS=(
  [red]="#ff0000"
  [green]="#00ff00"
  [blue]="#0000ff"
)

for key in "${!COLORS[@]}"; do
  printf "%-8s = %s\n" "$key" "${COLORS[$key]}"
done
