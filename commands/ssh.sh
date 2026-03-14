#!/usr/bin/env bash
# ── commands/ssh.sh ───────────────────────────────────────────
#  SSH key inspection and connection testing:
#    ghm test, ghm key
# ─────────────────────────────────────────────────────────────

cmd_test() {
  local alias="${1:-}"
  if [[ -z "$alias" ]]; then
    alias=$(_active_alias)
  fi
  if [[ -z "$alias" ]]; then
    _error "No alias given and no active account.  Run: ghm use <alias>"
    return 1
  fi
  if ! _account_exists "$alias"; then
    _error "Account '${alias}' not found.  Run: ghm list"
    return 1
  fi

  local username keyfile
  username=$(_get_meta "$alias" "username")
  keyfile=$(_get_meta  "$alias" "keyfile")

  echo ""
  _info "Testing SSH connection for '${alias}' (@${username})..."
  echo ""

  local result
  result=$(ssh -T -i "${keyfile}" \
    -o "StrictHostKeyChecking=no" \
    -o "IdentitiesOnly=yes" \
    -o "BatchMode=yes" \
    git@github.com 2>&1) || true

  if echo "$result" | grep -qi "successfully authenticated"; then
    _ok "${BOLD}Connection successful!${RESET}"
    echo -e "  ${DIM}${result}${RESET}"
    echo ""
    _ok "You're all set.  Run: ghm use ${alias}"
  else
    _error "Connection failed."
    echo -e "  ${DIM}${result}${RESET}"
    echo ""
    _warn "SSH key may not be added to GitHub yet."
    echo ""
    _info "Public key for '${alias}' (copying to clipboard now):"
    echo ""
    local pubkey
    pubkey=$(cat "${keyfile}.pub" 2>/dev/null || echo "")
    if [[ -z "$pubkey" ]]; then
      _error "Public key file not found: ${keyfile}.pub"
    else
      echo -e "${YELLOW}${pubkey}${RESET}"
      echo ""
      _copy_to_clipboard "$pubkey"
      _ok "Copied to clipboard."
      echo ""
      _info "Opening github.com/settings/keys in your browser..."
      _open_browser "https://github.com/settings/keys"
      echo ""
      if [[ -t 0 ]]; then
        printf "  Press Enter once you have saved the key on GitHub... "
        read -r
        echo ""
        _info "Re-testing connection..."
        result=$(ssh -T -i "${keyfile}" \
          -o "StrictHostKeyChecking=no" \
          -o "IdentitiesOnly=yes" \
          -o "BatchMode=yes" \
          git@github.com 2>&1) || true
        if echo "$result" | grep -qi "successfully authenticated"; then
          _ok "Connection successful now!"
        else
          _warn "Still failing. Double-check the key was saved correctly on GitHub."
          _dim  "Try again with: ghm test ${alias}"
        fi
      else
        _dim "After saving the key on GitHub, run: ghm test ${alias}"
      fi
    fi
  fi
  echo ""
}

cmd_key() {
  local alias="${1:-}"
  if [[ -z "$alias" ]]; then
    alias=$(_active_alias)
  fi
  if [[ -z "$alias" ]]; then
    _error "No alias given and no active account."; return 1
  fi
  if ! _account_exists "$alias"; then
    _error "Account '${alias}' not found."; return 1
  fi

  local keyfile username
  keyfile=$(_get_meta  "$alias" "keyfile")
  username=$(_get_meta "$alias" "username")

  echo ""
  _info "Public key for '${alias}' (@${username}):"
  echo ""
  local pubkey
  pubkey=$(cat "${keyfile}.pub" 2>/dev/null || true)
  if [[ -z "$pubkey" ]]; then
    _error "Key file not found: ${keyfile}.pub"
    return 1
  fi
  echo -e "${YELLOW}${pubkey}${RESET}"
  echo ""
  _copy_to_clipboard "$pubkey"
  _ok "Copied to clipboard!"
  echo ""
}