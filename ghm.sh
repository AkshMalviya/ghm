#!/usr/bin/env bash
# ============================================================
#  ghm — GitHub Multi-Account Manager
#  Windows Git Bash Edition  v1.1
#
#  Entry point — sources lib/ and commands/ then dispatches.
#
#  File layout:
#    ghm.sh                  <- this file (run this)
#    lib/
#      globals.sh            <- paths, colors, symbols
#      ui.sh                 <- _banner, _ok, _error, etc.
#      core.sh               <- SSH config, metadata, git identity
#    commands/
#      account.sh            <- add, remove, rename
#      switch.sh             <- use, list, current, whoami
#      ssh.sh                <- test, key
#      git.sh                <- apply
#      help.sh               <- help
# ============================================================

# No set -e — we handle errors per-command so that one
# cancelled step (e.g. closing the browser) never kills
# the whole session or wipes terminal output.
set -uo pipefail

# ── Locate the directory this script lives in ────────────────
# Works whether you run it as "ghm", "./ghm.sh", or full path.
GHM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Source all modules ────────────────────────────────────────
source "${GHM_SCRIPT_DIR}/lib/globals.sh"
source "${GHM_SCRIPT_DIR}/lib/ui.sh"
source "${GHM_SCRIPT_DIR}/lib/core.sh"
source "${GHM_SCRIPT_DIR}/commands/account.sh"
source "${GHM_SCRIPT_DIR}/commands/switch.sh"
source "${GHM_SCRIPT_DIR}/commands/ssh.sh"
source "${GHM_SCRIPT_DIR}/commands/git.sh"
source "${GHM_SCRIPT_DIR}/commands/help.sh"

# ── Bootstrap (create dirs, inject SSH Include) ───────────────
_init_dirs

# ── Command dispatcher ────────────────────────────────────────
case "${1:-help}" in
  add)             cmd_add    "${2:-}" ;;
  list|ls)         cmd_list ;;
  use|switch)      cmd_use    "${2:-}" ;;
  current)         cmd_current ;;
  whoami)          cmd_whoami ;;
  test)            cmd_test   "${2:-}" ;;
  key)             cmd_key    "${2:-}" ;;
  apply)           cmd_apply ;;
  remove|rm)       cmd_remove "${2:-}" ;;
  rename)          cmd_rename "${2:-}" "${3:-}" ;;
  help|--help|-h)  cmd_help ;;
  *)
    _error "Unknown command: ${1}"
    _dim   "Run: ghm help"
    exit 1
    ;;
esac