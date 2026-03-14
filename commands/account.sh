#!/usr/bin/env bash
# ── commands/account.sh ───────────────────────────────────────
#  Commands that create or destroy accounts:
#    ghm add, ghm remove, ghm rename
# ─────────────────────────────────────────────────────────────

cmd_add() {
  _banner
  _section "Add New GitHub Account"

  # ── TTY check ─────────────────────────────────────────────
  # "ghm add" needs interactive prompts. Without a TTY every
  # _read returns empty and the account saves with blank fields.
  if [[ ! -t 0 ]]; then
    _error "Interactive prompts are not available in this terminal."
    echo ""
    _dim "Run  ghm add  from Git Bash where prompts work correctly."
    echo ""
    return 1
  fi

  local alias="${1:-}"

  if [[ -z "$alias" ]]; then
    printf "  ${BOLD}Alias${RESET} ${DIM}(short name e.g. personal / office / freelance)${RESET}: "
    _read alias
    _dbg "alias after _read: '${alias}'"
  fi

  alias="${alias// /-}"
  alias="${alias,,}"
  if [[ -z "$alias" ]]; then
    _error "Alias cannot be empty."; return 1
  fi

  if _account_exists "$alias"; then
    _warn "Account '${alias}' already exists."
    printf "  Overwrite? [y/N]: "
    local confirm
    _read confirm
    if [[ "${confirm,,}" != "y" ]]; then
      _info "Aborted."; return 0
    fi
  fi

  printf "  ${BOLD}Label${RESET} ${DIM}(display name e.g. 'Office - Acme Corp')${RESET}: "
  local label
  _read label
  [[ -z "$label" ]] && label="$alias"

  printf "  ${BOLD}GitHub Username${RESET} ${DIM}(your @handle)${RESET}: "
  local username
  _read username
  if [[ -z "$username" ]]; then
    _error "Username cannot be empty."; return 1
  fi

  printf "  ${BOLD}GitHub Email${RESET}: "
  local email
  _read email
  if [[ -z "$email" ]]; then
    _error "Email cannot be empty."; return 1
  fi

  # ── SSH Key ───────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}SSH Key:${RESET}"
  echo -e "  ${DIM}[1]${RESET} Generate a new SSH key ${DIM}(recommended)${RESET}"
  echo -e "  ${DIM}[2]${RESET} Use an existing key file"
  printf "\n  Choice [1/2]: "
  local key_choice
  _read key_choice

  local keyfile
  local account_dir="${GHM_ACCOUNTS}/${alias}"
  mkdir -p "$account_dir"

  if [[ "${key_choice}" == "2" ]]; then
    printf "  Path to private key ${DIM}(forward slashes or ~)${RESET}: "
    _read keyfile
    keyfile="${keyfile/#\~/$HOME}"
    keyfile="${keyfile//\\//}"
    if [[ ! -f "$keyfile" ]]; then
      _error "Key file not found: $keyfile"
      _dim   "Tip: use paths like /c/Users/you/.ssh/id_rsa"
      return 1
    fi
  else
    keyfile="${SSH_DIR}/ghm_${alias}_ed25519"
    _info "Generating ED25519 SSH key..."
    ssh-keygen -t ed25519 -C "${email}" -f "${keyfile}" -N "" -q
    chmod 600 "${keyfile}" 2>/dev/null || true
    _ok "Key generated: ${keyfile}"
  fi

  # ── Save metadata (printf = guaranteed LF line endings) ───
  printf 'alias=%s\nlabel=%s\nusername=%s\nemail=%s\nkeyfile=%s\nadded=%s\n' \
    "${alias}" "${label}" "${username}" "${email}" "${keyfile}" \
    "$(date +%Y-%m-%dT%H:%M:%S)" \
    > "${account_dir}/meta"

  _rebuild_ssh_config

  # ── Show public key + instructions ───────────────────────
  echo ""
  _ok "Account ${BOLD}'${alias}'${RESET} saved!"
  echo ""

  local pubkey
  pubkey=$(cat "${keyfile}.pub")

  _line
  _section "Add this SSH key to GitHub"
  echo -e "${YELLOW}${pubkey}${RESET}"
  echo ""
  _line
  echo ""

  _copy_to_clipboard "$pubkey"
  _ok "Public key copied to your clipboard!"
  echo ""

  echo -e "  ${BOLD}Steps:${RESET}"
  echo -e "  ${DIM}1.${RESET} The key is already in your clipboard"
  echo -e "  ${DIM}2.${RESET} Click ${BOLD}New SSH key${RESET} in the browser window opening now"
  echo -e "  ${DIM}3.${RESET} Paste -> Give it a title -> Save"
  echo -e "  ${DIM}4.${RESET} Come back here and press ${BOLD}Enter${RESET} when done"
  echo ""

  _open_browser "https://github.com/settings/keys"

  if [[ -t 0 ]]; then
    printf "  Press Enter once you have saved the key on GitHub... "
    read -r   # plain read -r is fine here — we just need any keypress
    echo ""
  fi

  # ── Verify SSH connection ─────────────────────────────────
  _info "Verifying SSH connection..."
  local result
  result=$(ssh -T -i "${keyfile}" \
    -o "StrictHostKeyChecking=no" \
    -o "IdentitiesOnly=yes" \
    -o "BatchMode=yes" \
    git@github.com 2>&1) || true

  if echo "$result" | grep -qi "successfully authenticated"; then
    _ok "SSH connection verified — key is working!"
  else
    _warn "Could not verify SSH yet. Check later with: ${BOLD}ghm test ${alias}${RESET}"
    _dim  "This is fine if you haven't saved the key yet."
  fi

  echo ""

  # ── Set as active if this is the first account ───────────
  if [[ -z "$(_active_alias)" ]]; then
    _write_active "${alias}"
    _set_global_git_identity "$alias"
    _ok "Set '${alias}' as active account."
    _ok "Global git identity updated."
  else
    _dim "Run  ghm use ${alias}  to switch to this account."
  fi

  echo ""
}

cmd_remove() {
  local alias="${1:-}"
  if [[ -z "$alias" ]]; then
    _error "Usage: ghm remove <alias>"; return 1
  fi
  if ! _account_exists "$alias"; then
    _error "Account '${alias}' not found."; return 1
  fi

  local label username
  label=$(_get_meta    "$alias" "label")
  username=$(_get_meta "$alias" "username")

  echo ""
  _warn "About to remove: ${BOLD}${alias}${RESET}  (@${username} — ${label})"

  if [[ ! -t 0 ]]; then
    _error "Cannot confirm removal without an interactive terminal."
    _dim   "Run this command from Git Bash: ghm remove ${alias}"
    return 1
  fi

  printf "  Confirm? [y/N]: "
  local confirm
  _read confirm
  if [[ "${confirm,,}" != "y" ]]; then
    _info "Aborted."; return 0
  fi

  local keyfile
  keyfile=$(_get_meta "$alias" "keyfile")
  if echo "$keyfile" | grep -q "ghm_${alias}"; then
    rm -f "${keyfile}" "${keyfile}.pub" 2>/dev/null || true
    _ok "Removed SSH key pair."
  fi

  rm -rf "${GHM_ACCOUNTS:?}/${alias}"

  if [[ "$(_active_alias)" == "$alias" ]]; then
    rm -f "${GHM_ACTIVE}"
    _warn "Cleared active account.  Run: ghm use <alias>"
  fi

  _rebuild_ssh_config
  _ok "Account '${alias}' removed."
  echo ""
}

cmd_rename() {
  local old="${1:-}" new="${2:-}"
  if [[ -z "$old" || -z "$new" ]]; then
    _error "Usage: ghm rename <old-alias> <new-alias>"; return 1
  fi
  if ! _account_exists "$old"; then
    _error "Account '${old}' not found."; return 1
  fi
  if _account_exists "$new"; then
    _error "Account '${new}' already exists."; return 1
  fi

  mv "${GHM_ACCOUNTS}/${old}" "${GHM_ACCOUNTS}/${new}"
  sed -i "s/^alias=${old}$/alias=${new}/" "${GHM_ACCOUNTS}/${new}/meta"

  if [[ "$(_active_alias)" == "$old" ]]; then
    printf '%s' "${new}" > "${GHM_ACTIVE}"
  fi

  _rebuild_ssh_config
  _ok "Renamed '${old}' -> '${new}'"
}