#!/usr/bin/env bash
set -euo pipefail
SCRIPT_NAME="BuildFixture"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_ROOT/lib/std/import.sh"
.env
import std/string
import core/log

main() {
	string.trim "  hi  "
	log.info "ok"
}

main "$@"
