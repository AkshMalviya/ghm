#!/usr/bin/env bash
# ── ui.sh ────────────────────────────────────────────────────
#  Terminal output helpers: colors, banner, prompts.
#  Sourced by ghm.sh — requires globals.sh loaded first.
# ─────────────────────────────────────────────────────────────

_banner() {
  echo ""
  echo -e "${CYAN}${BOLD}  ██████╗ ██╗  ██╗███╗   ███╗${RESET}"
  echo -e "${CYAN}${BOLD} ██╔════╝ ██║  ██║████╗ ████║${RESET}"
  echo -e "${CYAN}${BOLD} ██║  ███╗███████║██╔████╔██║${RESET}"
  echo -e "${CYAN}${BOLD} ██║   ██║██╔══██║██║╚██╔╝██║${RESET}"
  echo -e "${CYAN}${BOLD} ╚██████╔╝██║  ██║██║ ╚═╝ ██║${RESET}"
  echo -e "${CYAN}${BOLD}  ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝${RESET}"
  echo -e "${DIM}  GitHub Multi-Account Manager v1.0 (Windows Git Bash)${RESET}"
  echo ""
}

_info()    { echo -e "${BLUE}  ${ARROW} $*${RESET}"; }
_ok()      { echo -e "${GREEN}  [${TICK}] $*${RESET}"; }
_warn()    { echo -e "${YELLOW}  [!] $*${RESET}"; }
_error()   { echo -e "${RED}  [${CROSS}] $*${RESET}"; }
_section() { echo -e "\n${BOLD}${MAGENTA}  $*${RESET}\n"; }
_dim()     { echo -e "${DIM}  $*${RESET}"; }
_line()    { echo -e "${DIM}  --------------------------------------------------${RESET}"; }