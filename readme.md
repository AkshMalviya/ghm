# GHM — GitHub Multi-Account Manager

### Windows Git Bash Edition

Switch between multiple GitHub accounts (personal, office, freelance...)
with a single command. All normal `git` commands work automatically after switching.

---

## Install (one time)

1. Open **Git Bash**
2. Navigate to where you downloaded these files
3. Run:

```bash
bash install.sh
source ~/.bashrc
```

That's it. `ghm` is now available in every Git Bash window.

---

## Setup your accounts (one time per account)

```bash
ghm add personal      # walks you through it, generates SSH key, opens GitHub
ghm add office        # add as many as you need
```

During `ghm add` it will:

- Ask for your GitHub username and email
- Generate a new SSH key for that account
- **Copy the public key to your clipboard**
- **Open github.com/settings/keys in your browser** so you can paste it
- Tell you to run `ghm test personal` to verify

---

## Daily usage

```bash
ghm use personal          # switch to personal account
git clone git@github.com:youruser/repo.git   # <- uses personal
git push                  # <- uses personal
git pull                  # <- uses personal

ghm use office            # switch to office account
git clone git@github.com:company/project.git  # <- uses office
git push                  # <- uses office
```

**No special syntax needed.** After `ghm use`, all standard git commands use the right key and identity.

---

## All commands

| Command                  | What it does                                              |
| ------------------------ | --------------------------------------------------------- |
| `ghm add [alias]`        | Add a GitHub account                                      |
| `ghm list`               | Show all accounts (like `nvm list`)                       |
| `ghm use <alias>`        | Switch active account — updates SSH + global git identity |
| `ghm current`            | Show who's active                                         |
| `ghm whoami`             | Show active GitHub username                               |
| `ghm test [alias]`       | Test SSH connection to GitHub                             |
| `ghm key [alias]`        | Show + copy public key to clipboard                       |
| `ghm apply`              | Override git identity for ONE repo (local only)           |
| `ghm remove <alias>`     | Remove an account                                         |
| `ghm rename <old> <new>` | Rename an alias                                           |

---

## How it works (for the curious)

When you run `ghm use personal`, three things happen:

1. **SSH config is rewritten** — `~/.ssh/ghm_config` gets a `Host github.com` block pointing to personal's SSH key. Since this file is `Include`d in `~/.ssh/config`, git's SSH automatically uses it.

2. **Global git identity is updated** — `git config --global user.name` and `user.email` are set to match the account, so commits show the right author.

3. **Active account is saved** — stored in `~/.ghm/active` so ghm remembers it across restarts.

This is why plain `git clone git@github.com:...` just works — SSH picks up the right key from config automatically.

---

## Troubleshooting

**`ghm: command not found` after install**

```bash
source ~/.bashrc
```

**`Permission denied (publickey)` on git push**

```bash
ghm test             # checks if SSH key is connected to GitHub
ghm key personal     # shows the key to add if missing
```

**Cloned a repo with wrong account?**

```bash
ghm use office       # switch account
ghm apply            # fix this repo's git identity
git remote set-url origin git@github.com:company/repo.git   # already SSH? you're good
```

**HTTPS remote (git clone https://...)**
Run `ghm apply` inside the repo — it auto-converts the remote to SSH for you.

---

## Files created by ghm

```
~/.ghm/
  active              <- which account is currently active
  accounts/
    personal/
      meta            <- username, email, key path
    office/
      meta

~/.ssh/
  ghm_personal_ed25519      <- private key (personal)
  ghm_personal_ed25519.pub  <- public key  (personal)
  ghm_office_ed25519        <- private key (office)
  ghm_office_ed25519.pub    <- public key  (office)
  ghm_config                <- SSH config written by ghm
  config                    <- your main SSH config (has Include for ghm_config)
```

ghm/
ghm.sh ← entry point only, sources everything
install.sh ← installer
lib/
globals.sh ← all paths, colors, symbols
ui.sh ← \_banner, \_ok, \_error, \_info, etc.
core.sh ← SSH config, metadata, git identity, Windows helpers
commands/
account.sh ← ghm add / remove / rename
switch.sh ← ghm use / list / current / whoami
ssh.sh ← ghm test / key
git.sh ← ghm apply
help.sh ← ghm help
