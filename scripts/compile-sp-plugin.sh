#!/usr/bin/env bash
# Compile SourceMod plugins (test-compile only, no .smx artifacts kept).
# Usage: ./scripts/compile-sp-plugin.sh [PluginName]
# No argument compiles all top-level plugins in the scripting folder.
# Example: ./scripts/compile-sp-plugin.sh EdictLimiter

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SM_DIR="$(cd "$SCRIPT_DIR/../roles/sourcemod/files/addons/sourcemod/scripting" && pwd)"

SPICOMP64="$(command -v spcomp64)"
if [ -z "$SPICOMP64" ]; then
	echo "Error: spcomp64 not found in PATH"
	exit 1
fi

SM_INCLUDE="$(dirname "$SPICOMP64")/include"
LOCAL_INCLUDE="$SM_DIR/include"

# Check includes exist
if [ ! -d "$SM_INCLUDE" ]; then
	echo "Error: MetaMod include directory not found: $SM_INCLUDE"
	exit 1
fi
if [ ! -d "$LOCAL_INCLUDE" ]; then
	echo "Error: Local SM include directory not found: $LOCAL_INCLUDE"
	exit 1
fi

SKIP_E_FLAG=("tf2attributes" "tf2attributes_example" "tf2attributes_test")

should_skip_e_flag() {
	local plugin_name="$1"
	for skip in "${SKIP_E_FLAG[@]}"; do
		if [[ "$plugin_name" == "$skip" ]]; then
			return 0
		fi
	done
	return 1
}

OUT_DIR="$(mktemp -d)"
trap "rm -rf $OUT_DIR" EXIT

compile_one() {
	local plugin="$1"
	local name
	name="$(basename "$plugin" .sp)"
	echo "Compiling $name ..."

	local extra_flags=()
	if should_skip_e_flag "$name"; then
		echo "  (skipping -E flag)"
	else
		extra_flags+=("-E")
	fi
	echo spcomp64 "${extra_flags[@]}" "$plugin" -o "$OUT_DIR/$name.smx" -i "$SM_INCLUDE" -i "$LOCAL_INCLUDE"
	spcomp64 "${extra_flags[@]}" "$plugin" -o "$OUT_DIR/$name.smx" -i "$SM_INCLUDE" -i "$LOCAL_INCLUDE"
}

NAME="${1:-}"
if [ -z "$NAME" ]; then
	count=0
	for plugin in "$SM_DIR"/*.sp; do
		compile_one "$plugin"
		count=$((count + 1))
	done
	echo "Compiled $count plugins successfully"
	exit 0
fi

PLUGIN="$SM_DIR/${NAME}.sp"
if [ ! -f "$PLUGIN" ]; then
	echo "Error: Plugin '$NAME' not found in $SM_DIR"
	echo "Available plugins:"
	ls "$SM_DIR"/*.sp 2>/dev/null | while read -r f; do
		basename "$f" .sp
	done
	exit 1
fi

compile_one "$PLUGIN"
echo "Compiled ${NAME}.smx successfully to $OUT_DIR"
