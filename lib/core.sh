#!/usr/bin/env bash
# ── core.sh ──────────────────────────────────────────────────
#  Core internals: directory init, SSH config management,
#  account metadata read/write, git identity helpers,
#  and Windows clipboard/browser utilities.
# ─────────────────────────────────────────────────────────────

# ── Debug logging ─────────────────────────────────────────────
# Set GHM_DEBUG=1 to enable: GHM_DEBUG=1 ghm add personal
GHM_DEBUG="${GHM_DEBUG:-0}"
_dbg() {
  [[ "$GHM_DEBUG" == "1" ]] || return 0
  echo -e "${DIM}  [DBG] $*${RESET}" >&2
}

# ── _read <varname> ───────────────────────────────────────────
# Drop-in for "read -r varname" that strips \r.
# Git Bash on Windows gets \r\n from the terminal; read -r strips
# \n but leaves \r attached, silently corrupting every variable.
_read() {
  local _varname="$1"
  local _val
  IFS= read -r _val <&0
  _val="${_val//$'\r'/}"
  printf -v "$_varname" '%s' "$_val"
  _dbg "_read ${_varname}='${_val}'"
}

# ── _open_browser <url> ───────────────────────────────────────
# Opens URL in default Windows browser.
# < /dev/null is critical — without it cmd.exe inherits the
# terminal stdin and the next "read" call gets EOF immediately.
_open_browser() {
  local url="$1"
  _dbg "_open_browser: ${url}"
  # PowerShell first — handles :// URLs reliably without misparse
  # cmd.exe /c start can fail on URLs with special chars
  powershell.exe -NoProfile -NonInteractive     -Command "Start-Process '${url}'" </dev/null 2>/dev/null     || cmd.exe /c start "" "${url}" </dev/null 2>/dev/null     || true
}

# ── _copy_to_clipboard <text> ─────────────────────────────────
# Copies text to Windows clipboard.
# BUG FIXED: do NOT redirect clip.exe stdin from /dev/null —
# that overrides the pipe and clip.exe gets empty input.
# clip.exe reads from the PIPE (left side), not from a second stdin.
_copy_to_clipboard() {
  local text="$1"
  _dbg "_copy_to_clipboard: ${#text} chars"
  if echo "${text}" | clip.exe 2>/dev/null; then
    _dbg "clip.exe succeeded"
    return 0
  fi
  if echo "${text}" | powershell.exe -NoProfile -NonInteractive \
       -Command "[Console]::InputEncoding=[System.Text.Encoding]::UTF8; \$input | Set-Clipboard" 2>/dev/null; then
    _dbg "powershell Set-Clipboard succeeded"
    return 0
  fi
  _dbg "_copy_to_clipboard: all methods failed"
  return 0  # non-fatal
}

# ── Directory + SSH config bootstrap ─────────────────────────
_init_dirs() {
  mkdir -p "${GHM_DIR}" "${GHM_ACCOUNTS}" "${SSH_DIR}"
  chmod 700 "${SSH_DIR}" 2>/dev/null || true

  if [[ ! -f "${SSH_CONFIG}" ]]; then
    touch "${SSH_CONFIG}"
  fi

  if ! grep -q "ghm_config" "${SSH_CONFIG}" 2>/dev/null; then
    local tmp
    tmp=$(mktemp)
    {
      echo "# GHM - GitHub Multi-Account Manager"
      echo "Include ${GHM_SSH_CONFIG}"
      echo ""
      cat "${SSH_CONFIG}"
    } > "$tmp"
    mv "$tmp" "${SSH_CONFIG}"
  fi

  touch "${GHM_SSH_CONFIG}" 2>/dev/null || true
  chmod 600 "${GHM_SSH_CONFIG}" 2>/dev/null || true
}

# ── Account metadata helpers ──────────────────────────────────

_active_alias() {
  if [[ ! -f "${GHM_ACTIVE}" ]]; then
    _dbg "_active_alias: file missing"
    echo ""; return
  fi
  local val
  val=$(tr -d '\r' < "${GHM_ACTIVE}")
  _dbg "_active_alias='${val}'"
  echo "${val}"
}

_account_exists() {
  [[ -f "${GHM_ACCOUNTS}/$1/meta" ]]
}

_get_meta() {
  local alias="$1" key="$2"
  local val
  val=$(grep "^${key}=" "${GHM_ACCOUNTS}/${alias}/meta" 2>/dev/null \
        | cut -d'=' -f2- \
        | tr -d '\r')
  _dbg "_get_meta ${alias}.${key}='${val}'"
  echo "${val}"
}

_list_aliases() {
  find "${GHM_ACCOUNTS}" -name "meta" -exec dirname {} \; 2>/dev/null \
    | while IFS= read -r d; do basename "$d"; done \
    | sort
}

# ── _write_active <alias> ─────────────────────────────────────
# Writes alias to the active file with guaranteed LF (no \r).
_write_active() {
  printf '%s\n' "$1" > "${GHM_ACTIVE}"
  _dbg "_write_active='$1' -> $(cat "${GHM_ACTIVE}" | tr -d '\n\r')"
}

# ── SSH config writer ─────────────────────────────────────────
_rebuild_ssh_config() {
  : > "${GHM_SSH_CONFIG}"
  local active
  active=$(_active_alias)
  _dbg "_rebuild_ssh_config active='${active}'"

  local _alias _keyfile _label
  while IFS= read -r _alias; do
    _keyfile=$(_get_meta "$_alias" "keyfile")
    _label=$(_get_meta   "$_alias" "label")
    cat >> "${GHM_SSH_CONFIG}" <<EOF
# GHM: ${_alias} (${_label})
Host github-${_alias}
  HostName github.com
  User git
  IdentityFile ${_keyfile}
  IdentitiesOnly yes

EOF
  done < <(_list_aliases)

  if [[ -n "$active" ]]; then
    local _active_key
    _active_key=$(_get_meta "$active" "keyfile")
    cat >> "${GHM_SSH_CONFIG}" <<EOF
# GHM active -> ${active}
Host github.com
  HostName github.com
  User git
  IdentityFile ${_active_key}
  IdentitiesOnly yes
EOF
  fi

  chmod 600 "${GHM_SSH_CONFIG}" 2>/dev/null || true
}

# ── Git identity ──────────────────────────────────────────────
_set_global_git_identity() {
  local alias="$1"
  local username email
  username=$(_get_meta "$alias" "username")
  email=$(_get_meta    "$alias" "email")
  _dbg "_set_global_git_identity: name='${username}' email='${email}'"

  git config --global user.name  "${username}"
  git config --global user.email "${email}"
  git config --global user.useConfigOnly false

  # Also write to the explicit Windows path so VS Code / GUI tools see it
  local win_gitconfig
  win_gitconfig=$(echo "$HOME" | sed 's|^/\([a-zA-Z]\)/|\1:/|')/.gitconfig
  if [[ -f "$win_gitconfig" ]] || [[ -d "$(dirname "$win_gitconfig")" ]]; then
    git config --file "$win_gitconfig" user.name  "${username}"
    git config --file "$win_gitconfig" user.email "${email}"
    git config --file "$win_gitconfig" user.useConfigOnly false
    _dbg "wrote to windows gitconfig: ${win_gitconfig}"
  fi
}