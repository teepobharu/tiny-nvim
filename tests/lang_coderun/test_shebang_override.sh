#!/usr/bin/env bash

set -euo pipefail

parts=("shebang" "override" "ok")
if [[ "${parts[1]}" != "override" ]]; then
	echo "unexpected array value"
	exit 1
fi

printf 'SHEBANG_OVERRIDE_OK:%s\n' "${parts[*]}"
