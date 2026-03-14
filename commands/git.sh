#!/usr/bin/env bash
# ── commands/git.sh ───────────────────────────────────────────
#  Git repository integration:
#    ghm apply  — set git identity for the current repo only
#
#  Note: the SSH key used for push/pull is always controlled
#  globally by "ghm use". This command only overrides the
#  git user.name / user.email locally for one repo.
# ─────────────────────────────────────────────────────────────

cmd_apply() {
  local active
  active=$(_active_alias)

  if [[ -z "$active" ]]; then
    _error "No active account.  Run: ghm use <alias>"
    return 1
  fi

  if ! git rev-parse --git-dir &>/dev/null; then
    _error "Not inside a git repository."
    _dim   "cd into your project folder first."
    return 1
  fi

  local username email label
  username=$(_get_meta "$active" "username")
  email=$(_get_meta    "$active" "email")
  label=$(_get_meta    "$active" "label")

  git config user.name          "${username}"
  git config user.email         "${email}"
  # Explicitly unset useConfigOnly for this repo so VS Code
  # doesn't block commits with "empty ident name" errors.
  git config user.useConfigOnly false

  # Auto-convert HTTPS remote to SSH so push/pull don't prompt for password
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  if echo "$remote_url" | grep -q "^https://github.com/"; then
    local new_url
    new_url=$(echo "$remote_url" | sed "s|https://github.com/|git@github.com:|")
    git remote set-url origin "$new_url"
    _ok "Converted remote from HTTPS to SSH"
  fi

  echo ""
  _ok "${BOLD}Applied '${active}'${RESET} to this repo"
  echo ""
  local repo_path
  repo_path=$(git rev-parse --show-toplevel 2>/dev/null || echo "current dir")
  printf "  ${DIM}%-12s${RESET} %s\n"                 "Repo:"     "${repo_path}"
  printf "  ${DIM}%-12s${RESET} %s\n"                 "Label:"    "${label}"
  printf "  ${DIM}%-12s${RESET} ${CYAN}@%s${RESET}\n" "Username:" "${username}"
  printf "  ${DIM}%-12s${RESET} %s\n"                 "Email:"    "${email}"
  if [[ -n "$remote_url" ]]; then
    printf "  ${DIM}%-12s${RESET} %s\n" "Remote:" "$(git remote get-url origin 2>/dev/null || echo '')"
  fi
  echo ""
  _dim "SSH key is still controlled globally by: ghm use <alias>"
  echo ""
}