#!/usr/bin/env bash
# Export the Godot Web release into docs/ for GitHub Pages.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT_VERSION="4.7.1"
GODOT_TAG="${GODOT_VERSION}-stable"
PRESET="Web"
OUT="docs/index.html"

find_godot() {
	if [[ -n "${GODOT:-}" && -x "${GODOT}" ]]; then
		echo "${GODOT}"
		return
	fi
	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return
	fi

	local win_console="/c/Users/kdroo/Downloads/Godot_v${GODOT_TAG}_win64.exe/Godot_v${GODOT_TAG}_win64_console.exe"
	local win_ps="C:/Users/kdroo/Downloads/Godot_v${GODOT_TAG}_win64.exe/Godot_v${GODOT_TAG}_win64_console.exe"
	if [[ -x "${win_console}" ]]; then
		echo "${win_console}"
		return
	fi
	if [[ -x "${win_ps}" ]]; then
		echo "${win_ps}"
		return
	fi

	local cached="/tmp/godot-install/Godot_v${GODOT_TAG}_linux.x86_64"
	if [[ -x "${cached}" ]]; then
		echo "${cached}"
		return
	fi
	return 1
}

install_linux_godot() {
	mkdir -p /tmp/godot-install
	local zip="/tmp/godot-install/godot.zip"
	curl -L --retry 3 -o "${zip}" \
		"https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/Godot_v${GODOT_TAG}_linux.x86_64.zip"
	# Quiet unzip so captured GODOT_BIN is only the binary path.
	unzip -qo "${zip}" -d /tmp/godot-install
	chmod +x "/tmp/godot-install/Godot_v${GODOT_TAG}_linux.x86_64"
	echo "/tmp/godot-install/Godot_v${GODOT_TAG}_linux.x86_64"
}

templates_dir() {
	if [[ -n "${APPDATA:-}" ]]; then
		echo "${APPDATA}/Godot/export_templates/${GODOT_VERSION}.stable"
		return
	fi
	echo "${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
}

ensure_templates() {
	local dest
	dest="$(templates_dir)"
	if [[ -f "${dest}/web_nothreads_release.zip" && -f "${dest}/web_nothreads_debug.zip" ]]; then
		return
	fi
	mkdir -p "${dest}" /tmp/godot-install/templates-extract
	local tpz="/tmp/godot-install/templates.tpz"
	if [[ ! -f "${tpz}" ]]; then
		curl -L --retry 3 -o "${tpz}" \
			"https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/Godot_v${GODOT_TAG}_export_templates.tpz"
	fi
	unzip -qo "${tpz}" templates/web_nothreads_debug.zip templates/web_nothreads_release.zip \
		-d /tmp/godot-install/templates-extract
	cp /tmp/godot-install/templates-extract/templates/web_nothreads_debug.zip \
		/tmp/godot-install/templates-extract/templates/web_nothreads_release.zip \
		"${dest}/"
	printf '%s.stable\n' "${GODOT_VERSION}" > "${dest}/version.txt"
}

GODOT_BIN="$(find_godot || true)"
if [[ -z "${GODOT_BIN}" ]]; then
	if [[ "$(uname -s)" == "Linux" ]]; then
		GODOT_BIN="$(install_linux_godot)"
	else
		echo "Godot ${GODOT_VERSION} not found. Set GODOT to the editor binary." >&2
		exit 1
	fi
fi

ensure_templates

write_build_stamp() {
	# Web builds have no git — bake short SHA (+ date) for the start-menu stamp.
	local sha date_str
	sha="$(git -C "${ROOT}" rev-parse --short HEAD)"
	date_str="$(date -u +%Y-%m-%d)"
	printf '%s  %s\n' "${sha}" "${date_str}" > "${ROOT}/version.txt"
	echo "Build stamp: ${sha}  ${date_str}"
}

write_build_stamp

echo "Exporting ${PRESET} with ${GODOT_BIN}"
"${GODOT_BIN}" --headless --path "${ROOT}" --export-release "${PRESET}" "${OUT}"
# Also drop a plain-text copy next to the Pages artifacts for easy inspection.
cp "${ROOT}/version.txt" "${ROOT}/docs/version.txt"
echo "Wrote ${OUT} (stamp $(tr -d '\n' < "${ROOT}/version.txt"))"
