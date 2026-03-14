#!/usr/bin/env bash
# ============================================================
#  GHM Installer — Windows Git Bash
#  Run once:  bash install.sh
#
#  Installs to:
#    ~/.ghm-bin/          <- all scripts live here
#      ghm.sh
#      lib/
#      commands/
#    ~/bin/ghm            <- single launcher file (what you type)
# ============================================================

set -uo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

_ok()    { echo -e "${GREEN}  [v] $*${RESET}"; }
_info()  { echo -e "${CYAN}  ->  $*${RESET}"; }
_warn()  { echo -e "${YELLOW}  [!] $*${RESET}"; }
_error() { echo -e "${RED}  [x] $*${RESET}"; }

echo ""
echo -e "${CYAN}${BOLD}  GHM Installer — Windows Git Bash${RESET}"
echo ""

# ── Sanity checks ─────────────────────────────────────────────
if ! command -v git &>/dev/null; then
  _error "Git not found. Install Git for Windows first."
  echo -e "${DIM}  -> https://git-scm.com/download/win${RESET}"
  exit 1
fi
if ! command -v ssh-keygen &>/dev/null; then
  _error "ssh-keygen not found. Run this inside Git Bash, not CMD or PowerShell."
  exit 1
fi
_ok "Git Bash environment OK"

# ── Verify all source files exist ─────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRED_FILES=(
  "ghm.sh"
  "lib/globals.sh"
  "lib/ui.sh"
  "lib/core.sh"
  "commands/account.sh"
  "commands/switch.sh"
  "commands/ssh.sh"
  "commands/git.sh"
  "commands/help.sh"
)

echo ""
_info "Checking source files..."
all_ok=true
for f in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "${SCRIPT_DIR}/${f}" ]]; then
    _error "Missing: ${f}"
    all_ok=false
  fi
done
if [[ "$all_ok" != true ]]; then
  _error "Some files are missing. Make sure you kept the full folder structure."
  exit 1
fi
_ok "All source files present"

# ── Clean up any previous install ─────────────────────────────
# ~/bin/ghm may exist as a FILE (old single-file install) or as a
# DIRECTORY (broken previous run). Remove either.
echo ""
_info "Cleaning up any previous install..."

if [[ -f "${HOME}/bin/ghm" ]]; then
  rm -f "${HOME}/bin/ghm"
  _ok "Removed old ~/bin/ghm file"
fi
if [[ -d "${HOME}/bin/ghm" ]]; then
  rm -rf "${HOME}/bin/ghm"
  _ok "Removed old ~/bin/ghm directory"
fi
rm -f "${HOME}/bin/ghm-run" 2>/dev/null || true

# ── Install all scripts to ~/.ghm-bin/ ────────────────────────
INSTALL_BASE="${HOME}/.ghm-bin"

_info "Installing scripts to ${INSTALL_BASE} ..."

rm -rf "${INSTALL_BASE}"
mkdir -p "${INSTALL_BASE}/lib"
mkdir -p "${INSTALL_BASE}/commands"

cp "${SCRIPT_DIR}/ghm.sh"              "${INSTALL_BASE}/ghm.sh"
cp "${SCRIPT_DIR}/lib/globals.sh"      "${INSTALL_BASE}/lib/globals.sh"
cp "${SCRIPT_DIR}/lib/ui.sh"           "${INSTALL_BASE}/lib/ui.sh"
cp "${SCRIPT_DIR}/lib/core.sh"         "${INSTALL_BASE}/lib/core.sh"
cp "${SCRIPT_DIR}/commands/account.sh" "${INSTALL_BASE}/commands/account.sh"
cp "${SCRIPT_DIR}/commands/switch.sh"  "${INSTALL_BASE}/commands/switch.sh"
cp "${SCRIPT_DIR}/commands/ssh.sh"     "${INSTALL_BASE}/commands/ssh.sh"
cp "${SCRIPT_DIR}/commands/git.sh"     "${INSTALL_BASE}/commands/git.sh"
cp "${SCRIPT_DIR}/commands/help.sh"    "${INSTALL_BASE}/commands/help.sh"

chmod +x "${INSTALL_BASE}/ghm.sh"
_ok "Scripts installed to ~/.ghm-bin/"

# ── Create ~/bin/ghm launcher (a plain file) ──────────────────
mkdir -p "${HOME}/bin"

cat > "${HOME}/bin/ghm" << 'LAUNCHER'
#!/usr/bin/env bash
exec "${HOME}/.ghm-bin/ghm.sh" "$@"
LAUNCHER

chmod +x "${HOME}/bin/ghm"
_ok "Launcher created: ~/bin/ghm  (Git Bash)"

# ── Create CMD / PowerShell wrapper ───────────────────────────
# CMD can't run bash scripts directly. We write a ghm.bat that
# calls Git Bash with the ghm script — no cmd.exe calls needed,
# we derive all Windows paths directly from bash variables.

echo ""
_info "Creating CMD / PowerShell wrapper..."

# Convert $HOME from Unix style (/c/Users/HP) to Windows style (C:\Users\HP)
# using only bash string operations — no cmd.exe call, nothing hangs.
_to_win_path() {
  echo "$1" | sed 's|^/\([a-zA-Z]\)/|\1:\\|' | sed 's|/|\\|g'
}

WIN_HOME=$(_to_win_path "$HOME")
WIN_GHM_BIN="${WIN_HOME}\\.ghm-bin"

# Find bash.exe by walking known Git for Windows install locations.
# We stay entirely in bash — no cmd.exe/where.exe calls.
GIT_BASH=""
for candidate in \
  "/c/Program Files/Git/bin/bash.exe" \
  "/c/Program Files (x86)/Git/bin/bash.exe" \
  "/c/Git/bin/bash.exe"
do
  if [[ -f "$candidate" ]]; then
    GIT_BASH="$candidate"
    break
  fi
done

# Last resort: derive from $BASH itself (Git Bash sets $BASH)
if [[ -z "$GIT_BASH" ]] && [[ -n "${BASH:-}" ]]; then
  DERIVED="${BASH%/bash}.exe"   # swap /usr/bin/bash -> /usr/bin/bash.exe won't work,
  # but Git Bash's real bash lives at /c/Program Files/Git/bin/bash.exe
  # $BASH is typically /usr/bin/bash inside the MINGW env, so look up one more level
  GIT_ROOT=$(cd "$(dirname "$BASH")/../../.." 2>/dev/null && pwd || true)
  if [[ -f "${GIT_ROOT}/bin/bash.exe" ]]; then
    GIT_BASH="${GIT_ROOT}/bin/bash.exe"
  fi
fi

if [[ -z "$GIT_BASH" ]]; then
  _warn "Could not locate bash.exe — skipping CMD wrapper."
  _dim  "ghm still works fine inside Git Bash."
  _dim  "To fix CMD support manually, see README or run: ghm help"
else
  WIN_BASH=$(_to_win_path "$GIT_BASH")

  mkdir -p "${HOME}/bin"

  # Find winpty.exe — ships with Git for Windows, gives CMD a real TTY
  # so that "read" prompts work interactively (ghm add, ghm use picker).
  WIN_WINPTY=""
  WINPTY_UNIX="${GIT_BASH%/bin/bash.exe}/usr/bin/winpty.exe"
  if [[ -f "$WINPTY_UNIX" ]]; then
    WIN_WINPTY=$(_to_win_path "$WINPTY_UNIX")
  fi

  mkdir -p "${HOME}/bin"
  if [[ -n "$WIN_WINPTY" ]]; then
    # With winpty: read/prompts work in CMD — full interactive support
    cat > "${HOME}/bin/ghm.bat" << BATEOF
@echo off
"${WIN_WINPTY}" "${WIN_BASH}" --login -i "${WIN_GHM_BIN}\ghm.sh" %*
BATEOF
    _ok "CMD wrapper created with winpty (full interactive support)"
  else
    # Without winpty: non-interactive commands work (use/list/test/key)
    # but prompts (ghm add) won't — warn the user.
    cat > "${HOME}/bin/ghm.bat" << BATEOF
@echo off
"${WIN_BASH}" --login "${WIN_GHM_BIN}\ghm.sh" %*
BATEOF
    _warn "winpty not found — CMD wrapper created without interactive support."
    _dim  "Commands like ghm use/list/test/key will work in CMD."
    _dim  "For ghm add, use Git Bash instead."
  fi
  _ok "CMD wrapper: %USERPROFILE%\bin\ghm.bat"

  # Add %USERPROFILE%\bin to Windows PATH using PowerShell (non-interactive,
  # no window, doesn't hang). setx alone has a 1024-char PATH limit bug.
  WIN_BIN="${WIN_HOME}\\bin"
  powershell.exe -NoProfile -NonInteractive -Command "
    \$current = [Environment]::GetEnvironmentVariable('PATH','User')
    if (\$current -notlike '*${WIN_BIN}*') {
      [Environment]::SetEnvironmentVariable('PATH', '${WIN_BIN};' + \$current, 'User')
    }
  " 2>/dev/null && _ok "Added %USERPROFILE%\\bin to Windows PATH" \
                 || _warn "Could not update Windows PATH automatically — add %USERPROFILE%\\bin manually"
fi

# ── Add ~/bin to PATH if not already there ────────────────────
BASHRC="${HOME}/.bashrc"
BASH_PROFILE="${HOME}/.bash_profile"

_add_path_to() {
  local rc="$1"
  if [[ -f "$rc" ]] && grep -q 'GHM\|ghm-bin\|bin:' "$rc" 2>/dev/null; then
    return
  fi
  {
    echo ""
    echo "# GHM - GitHub Multi-Account Manager"
    echo 'export PATH="$HOME/bin:$PATH"'
  } >> "$rc"
}

if ! echo "$PATH" | tr ':' '\n' | grep -qx "${HOME}/bin"; then
  _add_path_to "$BASHRC"
  if [[ ! -f "$BASH_PROFILE" ]]; then
    echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' > "$BASH_PROFILE"
  elif ! grep -q '.bashrc' "$BASH_PROFILE" 2>/dev/null; then
    echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> "$BASH_PROFILE"
  fi
  _add_path_to "$BASH_PROFILE"
  _ok "Added ~/bin to PATH in ~/.bashrc"
else
  _ok "~/bin already in PATH"
fi

# ── Verify it works ───────────────────────────────────────────
echo ""
_info "Verifying install..."
if bash "${INSTALL_BASE}/ghm.sh" help > /dev/null 2>&1; then
  _ok "ghm runs correctly"
else
  _warn "Something went wrong. Try: bash ~/.ghm-bin/ghm.sh help"
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
echo -e "${DIM}  ------------------------------------------------${RESET}"
echo -e "${GREEN}${BOLD}  Installation complete!${RESET}"
echo -e "${DIM}  ------------------------------------------------${RESET}"
echo ""
echo -e "  ${BOLD}In Git Bash${RESET} — activate now:"
echo -e "  ${BOLD}source ~/.bashrc${RESET}"
echo ""
echo -e "  ${BOLD}In CMD / PowerShell${RESET} — open a ${BOLD}new${RESET} window (PATH update takes effect)"
echo ""
echo -e "  Then in either terminal:"
echo -e "  ${BOLD}ghm add personal${RESET}   ${DIM}# add first account${RESET}"
echo -e "  ${BOLD}ghm add office${RESET}     ${DIM}# add second account${RESET}"
echo -e "  ${BOLD}ghm list${RESET}           ${DIM}# see all accounts${RESET}"
echo -e "  ${BOLD}ghm use personal${RESET}   ${DIM}# switch accounts${RESET}"
echo ""
echo -e "${DIM}  Note: ghm add / interactive prompts work best in Git Bash.${RESET}"
echo -e "${DIM}  ghm use / list / test / key all work fine in CMD too.${RESET}"
echo ""