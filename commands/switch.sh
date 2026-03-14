#!/usr/bin/env bash
# ── commands/switch.sh ────────────────────────────────────────
#  Commands for switching and inspecting the active account:
#    ghm use, ghm list, ghm current, ghm whoami
# ─────────────────────────────────────────────────────────────

cmd_list() {
  _banner
  local aliases=()
  while IFS= read -r a; do aliases+=("$a"); done < <(_list_aliases)

  if [[ ${#aliases[@]} -eq 0 ]]; then
    _warn "No accounts yet.  Run: ghm add"
    echo ""; return
  fi

  local active
  active=$(_active_alias)
  _section "GitHub Accounts"

  for alias in "${aliases[@]}"; do
    local label username email keyfile
    label=$(_get_meta    "$alias" "label")
    username=$(_get_meta "$alias" "username")
    email=$(_get_meta    "$alias" "email")
    keyfile=$(_get_meta  "$alias" "keyfile")

    local key_ok="${RED}[x] key missing${RESET}"
    [[ -f "$keyfile" ]] && key_ok="${GREEN}[v] key ok${RESET}"

    if [[ "$alias" == "$active" ]]; then
      echo -e "  ${GREEN}${BOLD}[*] ${alias}${RESET}  ${DIM}(active)${RESET}"
    else
      echo -e "  ${CYAN}[-] ${alias}${RESET}"
    fi

    printf "    ${DIM}%-12s${RESET} %s\n"     "Label:"    "${label}"
    printf "    ${DIM}%-12s${RESET} @%s\n"    "Username:" "${username}"
    printf "    ${DIM}%-12s${RESET} %s\n"     "Email:"    "${email}"
    printf "    ${DIM}%-12s${RESET} %s  %b\n" "SSH Key:"  "${keyfile##*/}" "${key_ok}"
    echo ""
  done

  _line
  _dim "Switch: ghm use <alias>   |   Add: ghm add   |   Test: ghm test <alias>"
  echo ""
}

cmd_use() {
  local alias="${1:-}"

  if [[ -z "$alias" ]]; then
    # No argument given — need interactive picker, requires a TTY
    if [[ ! -t 0 ]]; then
      _error "Usage: ghm use <alias>"
      echo ""
      _dim "Tip: ghm list  to see all aliases"
      return 1
    fi

    _banner
    _section "Switch Account"

    local aliases=()
    while IFS= read -r a; do aliases+=("$a"); done < <(_list_aliases)
    if [[ ${#aliases[@]} -eq 0 ]]; then
      _warn "No accounts added. Run: ghm add"; return 1
    fi

    local active
    active=$(_active_alias)
    echo ""

    local i=1
    for a in "${aliases[@]}"; do
      local lbl usr
      lbl=$(_get_meta "$a" "label")
      usr=$(_get_meta "$a" "username")
      if [[ "$a" == "$active" ]]; then
        echo -e "  ${GREEN}${BOLD}[${i}] ${a}${RESET}  @${usr}  ${DIM}${lbl}  (active)${RESET}"
      else
        echo -e "  ${CYAN}[${i}]${RESET} ${BOLD}${a}${RESET}  @${usr}  ${DIM}${lbl}${RESET}"
      fi
      ((i++))
    done

    echo ""
    printf "  Select [1-${#aliases[@]}]: "
    _read choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#aliases[@]} )); then
      _error "Invalid choice."; return 1
    fi
    alias="${aliases[$((choice-1))]}"
  fi

  if ! _account_exists "$alias"; then
    _error "Account '${alias}' not found.  Run: ghm list"
    return 1
  fi

  _write_active "${alias}"
  _rebuild_ssh_config
  _set_global_git_identity "$alias"

  local label username email
  label=$(_get_meta    "$alias" "label")
  username=$(_get_meta "$alias" "username")
  email=$(_get_meta    "$alias" "email")

  echo ""
  _ok "${BOLD}Switched to '${alias}'${RESET}"
  echo ""
  printf "  ${DIM}%-12s${RESET} %s\n"                 "Label:"    "${label}"
  printf "  ${DIM}%-12s${RESET} ${CYAN}@%s${RESET}\n" "Username:" "${username}"
  printf "  ${DIM}%-12s${RESET} %s\n"                 "Email:"    "${email}"
  echo ""
  _ok "SSH config updated   -> git clone/push/pull now use @${username}"
  _ok "Global git identity  -> user.name + user.email updated"
  echo ""
  _dim "To override for one specific repo only: cd into it then run: ghm apply"
  echo ""
}

cmd_current() {
  local active
  active=$(_active_alias)

  if [[ -z "$active" ]]; then
    _warn "No active account set.  Run: ghm use <alias>"
    return
  fi

  local label username email keyfile
  label=$(_get_meta    "$active" "label")
  username=$(_get_meta "$active" "username")
  email=$(_get_meta    "$active" "email")
  keyfile=$(_get_meta  "$active" "keyfile")

  echo ""
  echo -e "  ${GREEN}${BOLD}Active GitHub Account${RESET}"
  _line
  printf "  ${DIM}%-12s${RESET} ${BOLD}%s${RESET}\n"  "Alias:"    "${active}"
  printf "  ${DIM}%-12s${RESET} %s\n"                 "Label:"    "${label}"
  printf "  ${DIM}%-12s${RESET} ${CYAN}@%s${RESET}\n" "Username:" "${username}"
  printf "  ${DIM}%-12s${RESET} %s\n"                 "Email:"    "${email}"
  printf "  ${DIM}%-12s${RESET} %s\n"                 "SSH Key:"  "${keyfile}"
  echo ""
  echo -e "  ${BOLD}Global git config:${RESET}"
  printf "  ${DIM}%-12s${RESET} %s\n" "user.name:"  "$(git config --global user.name  2>/dev/null || echo '(not set)')"
  printf "  ${DIM}%-12s${RESET} %s\n" "user.email:" "$(git config --global user.email 2>/dev/null || echo '(not set)')"
  echo ""
}

cmd_whoami() {
  local active
  active=$(_active_alias)
  if [[ -z "$active" ]]; then
    _warn "No active account.  Run: ghm use <alias>"
    return 1
  fi
  local username
  username=$(_get_meta "$active" "username")
  echo -e "  ${GREEN}@${username}${RESET}  ${DIM}(alias: ${active})${RESET}"
}