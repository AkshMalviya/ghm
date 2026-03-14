#!/usr/bin/env bash
# ── commands/help.sh ──────────────────────────────────────────
#  Usage reference: ghm help
# ─────────────────────────────────────────────────────────────

cmd_help() {
  _banner
  echo -e "  ${BOLD}Usage:${RESET}  ghm <command> [options]"
  echo ""
  _line
  echo -e "  ${BOLD}${CYAN}Account Management${RESET}"
  _line
  printf "  ${GREEN}%-24s${RESET} %s\n" "add [alias]"         "Add a new GitHub account"
  printf "  ${GREEN}%-24s${RESET} %s\n" "remove <alias>"      "Remove an account"
  printf "  ${GREEN}%-24s${RESET} %s\n" "rename <old> <new>"  "Rename an alias"
  echo ""
  _line
  echo -e "  ${BOLD}${CYAN}Switching & Status${RESET}"
  _line
  printf "  ${GREEN}%-24s${RESET} %s\n" "list  (ls)"          "Show all accounts"
  printf "  ${GREEN}%-24s${RESET} %s\n" "use <alias>"         "Switch account (updates SSH + git identity)"
  printf "  ${GREEN}%-24s${RESET} %s\n" "current"             "Show active account details"
  printf "  ${GREEN}%-24s${RESET} %s\n" "whoami"              "Show active GitHub username"
  echo ""
  _line
  echo -e "  ${BOLD}${CYAN}SSH Keys${RESET}"
  _line
  printf "  ${GREEN}%-24s${RESET} %s\n" "test [alias]"        "Test SSH connection to GitHub"
  printf "  ${GREEN}%-24s${RESET} %s\n" "key [alias]"         "Show + copy public key to clipboard"
  echo ""
  _line
  echo -e "  ${BOLD}${CYAN}Git Repo${RESET}"
  _line
  printf "  ${GREEN}%-24s${RESET} %s\n" "apply"               "Set git identity for current repo only"
  echo ""
  _line
  echo -e "  ${BOLD}${CYAN}How it works${RESET}"
  _line
  _dim "ghm use <alias>  writes the active key into ~/.ssh/ghm_config"
  _dim "SSH reads that file for every git command automatically."
  _dim ""
  _dim "After:  ghm use personal"
  _dim "  git clone git@github.com:you/repo   <- personal key"
  _dim "  git push / git pull                  <- personal key"
  _dim ""
  _dim "After:  ghm use office"
  _dim "  git push                             <- office key"
  echo ""
}