#!/usr/bin/env bash
# ── globals.sh ───────────────────────────────────────────────
#  All paths, colors, and symbol constants used across ghm.
#  Sourced by ghm.sh before anything else runs.
# ─────────────────────────────────────────────────────────────

# Paths
GHM_DIR="${HOME}/.ghm"
GHM_ACCOUNTS="${GHM_DIR}/accounts"
GHM_ACTIVE="${GHM_DIR}/active"
SSH_DIR="${HOME}/.ssh"
GHM_SSH_CONFIG="${SSH_DIR}/ghm_config"
SSH_CONFIG="${SSH_DIR}/config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Symbols (ASCII safe for Git Bash)
TICK="v"
CROSS="x"
ARROW="->"
STAR="*"
CIRCLE="-"