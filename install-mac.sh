#!/usr/bin/env bash
# FOAD Dev Setup - macOS
# Version 2.1.1
#
# Installs: Homebrew, Git, Node.js/npm, Python 3, Google Antigravity IDE,
# Claude Code, and beginner starter files. Reruns preserve existing workshop files.
#
# Website command:
# curl -fsSL https://raw.githubusercontent.com/masterFoad/agent_setup/v2.1.1/install-mac.sh -o /tmp/foad-install-mac.sh
# /bin/bash /tmp/foad-install-mac.sh
#
# WORKSHOP INSTRUCTOR NOTES:
# - Ask attendees to run this before the workshop if possible. Downloads are large,
#   and a room full of people installing at once can overwhelm venue Wi-Fi.
# - Attendees need macOS 14+, an Administrator account, their Mac login password,
#   and a Google account for Antigravity IDE.
# - The full setup requires macOS 14+, matching Homebrew's supported baseline.
# - Claude Code requires a paid Claude plan or another supported account/API setup.
# - On a new Mac, Homebrew may install Apple's Command Line Tools. This can take
#   5-15 minutes and may appear inactive for stretches.
# - Written for macOS's built-in /bin/bash 3.2. Do not add Bash 4+ features.

set -u

SCRIPT_VERSION="2.1.1"
TOTAL_STEPS=11
STEP_NUM=0
SUMMARY_NOTE=""

# ---------- Pretty output (colors only in a real terminal) ----------
if [[ -t 1 ]]; then
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RESET=$'\033[0m'
else
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
  C_BOLD=""
  C_DIM=""
  C_RESET=""
fi

step() {
  STEP_NUM=$((STEP_NUM + 1))
  printf '\n%s=== [%d/%d] %s ===%s\n' "$C_BOLD" "$STEP_NUM" "$TOTAL_STEPS" "$1" "$C_RESET"
}

ok()   { printf '%s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$1"; }
fail() { printf '%s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$1"; }
note() { printf '%s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }

# ---------- Result tracking ----------
RESULT_NAMES=()
RESULT_STATES=()

record() { # record <OK|WARN|FAIL> <name>
  RESULT_STATES+=("$1")
  RESULT_NAMES+=("$2")
}

results_have_state() {
  local wanted="$1"
  local i

  if [[ ${#RESULT_STATES[@]} -eq 0 ]]; then
    return 1
  fi

  for i in "${!RESULT_STATES[@]}"; do
    if [[ "${RESULT_STATES[$i]}" == "$wanted" ]]; then
      return 0
    fi
  done
  return 1
}

print_summary() {
  local i
  local had_warning=0
  local had_failure=0

  if [[ ${#RESULT_NAMES[@]} -eq 0 ]]; then
    return 0
  fi

  printf '\n%s=== Setup summary ===%s\n' "$C_BOLD" "$C_RESET"

  for i in "${!RESULT_NAMES[@]}"; do
    case "${RESULT_STATES[$i]}" in
      OK)
        printf '  %s✔%s %s\n' "$C_GREEN" "$C_RESET" "${RESULT_NAMES[$i]}"
        ;;
      WARN)
        printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "${RESULT_NAMES[$i]}"
        had_warning=1
        ;;
      FAIL)
        printf '  %s✘%s %s\n' "$C_RED" "$C_RESET" "${RESULT_NAMES[$i]}"
        had_failure=1
        ;;
    esac
  done

  if [[ -n "$SUMMARY_NOTE" ]]; then
    printf '\n%sNext action:%s %s\n' "$C_BOLD" "$C_RESET" "$SUMMARY_NOTE"
  elif [[ $had_failure -eq 1 ]]; then
    printf '\n%sFix the failed items above, then rerun this setup.%s Existing workshop files are preserved.\n' "$C_YELLOW" "$C_RESET"
  elif [[ $had_warning -eq 1 ]]; then
    printf '\n%sSetup completed with warnings.%s Review the items marked ! above.\n' "$C_YELLOW" "$C_RESET"
  else
    printf '\n%s🎉 Everything installed successfully!%s\n' "$C_GREEN$C_BOLD" "$C_RESET"
  fi
}

stop_setup() { # stop_setup <result name> <failure message> <next action>
  fail "$2"
  record FAIL "$1"
  SUMMARY_NOTE="$3"
  print_summary
  exit 1
}

# Invoked indirectly by the signal trap below.
# shellcheck disable=SC2329
on_interrupt() {
  printf '\n\n%sSetup was interrupted.%s Nothing is broken. Rerun it at any time to continue.\n' "$C_YELLOW" "$C_RESET"
  exit 130
}
trap on_interrupt INT TERM

# ---------- Helpers ----------
append_once() {
  local file="$1"
  local line="$2"

  if ! mkdir -p "$(dirname "$file")" || ! touch "$file"; then
    fail "Could not access shell profile: $file"
    return 1
  fi

  if ! grep -Fqx "$line" "$file" 2>/dev/null; then
    if ! printf '\n%s\n' "$line" >> "$file"; then
      fail "Could not update shell profile: $file"
      return 1
    fi
  fi
}

load_brew_path() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return 0
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    return 0
  fi

  return 1
}

# These lines must be written literally.
# shellcheck disable=SC2016
persist_brew_path() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    append_once "$HOME/.zprofile" 'eval "$(/opt/homebrew/bin/brew shellenv)"' || return 1
    append_once "$HOME/.bash_profile" 'eval "$(/opt/homebrew/bin/brew shellenv)"' || return 1
  elif [[ -x /usr/local/bin/brew ]]; then
    append_once "$HOME/.zprofile" 'eval "$(/usr/local/bin/brew shellenv)"' || return 1
    append_once "$HOME/.bash_profile" 'eval "$(/usr/local/bin/brew shellenv)"' || return 1
  fi
}

# PATH must expand when the profile is loaded.
# shellcheck disable=SC2016
ensure_tool_path() {
  local path_line='export PATH="$HOME/.local/bin:$HOME/.claude/bin:$HOME/.claude/local:$PATH"'

  append_once "$HOME/.zprofile" "$path_line" || return 1
  append_once "$HOME/.bash_profile" "$path_line" || return 1
  export PATH="$HOME/.local/bin:$HOME/.claude/bin:$HOME/.claude/local:$PATH"
}

is_admin_user() {
  local current_user
  local gid

  current_user="$(id -un)"
  for gid in $(id -G "$current_user" 2>/dev/null); do
    # The built-in macOS admin group has GID 80.
    if [[ "$gid" == "80" ]]; then
      return 0
    fi
  done
  return 1
}

install_homebrew() {
  local installer

  echo "Homebrew is not installed yet."
  echo ""

  if [[ "$(id -u)" == "0" ]]; then
    stop_setup \
      "Homebrew" \
      "This setup was started as root (with sudo). Homebrew must be installed from your normal Mac account." \
      "Close this Terminal window, open Terminal normally, and run the setup command again without 'sudo'."
  fi

  if ! is_admin_user; then
    echo "Homebrew's first installation needs an Administrator account."
    echo "Your current Mac account is not an Administrator."
    echo ""
    echo "To fix this:"
    echo "1. Open System Settings."
    echo "2. Open Users & Groups."
    echo "3. Ask the Mac owner or administrator to enable administrator access for this account,"
    echo "   or ask them to run this setup from an Administrator account."
    echo "4. Sign out and sign back in after changing the account type."
    echo ""
    stop_setup \
      "Homebrew" \
      "Administrator access is required for the first Homebrew installation." \
      "Use an Administrator account, then rerun this setup."
  fi

  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "Homebrew needs an interactive Terminal so it can ask for confirmation and a password."
    echo "Do not run this installer using 'curl ... | bash'."
    echo ""
    echo "Run this exact command in Apple's Terminal app:"
    echo 'curl -fsSL https://raw.githubusercontent.com/masterFoad/agent_setup/v2.1.1/install-mac.sh -o /tmp/foad-install-mac.sh'
    echo '/bin/bash /tmp/foad-install-mac.sh'
    echo ""
    stop_setup \
      "Homebrew" \
      "No interactive Terminal was detected." \
      "Open Terminal and run the setup with the recommended /bin/bash -c command."
  fi

  echo "Homebrew needs administrator permission for its first installation."
  echo "macOS will ask for your normal Mac login password."
  echo "Nothing will appear while you type the password. Type it anyway, then press Return."
  echo ""

  if ! /usr/bin/sudo -v; then
    echo ""
    stop_setup \
      "Homebrew" \
      "macOS did not grant administrator permission." \
      "Check the password and account permissions, then rerun this setup."
  fi

  note "On a new Mac, Homebrew may also install Apple's Command Line Tools."
  note "That can take 5-15 minutes and may appear stuck. Let it finish."
  note "Homebrew will show what it plans to change and ask you to press Return."
  echo ""

  installer="$(mktemp "${TMPDIR:-/tmp}/foad-homebrew.XXXXXX")" || {
    stop_setup \
      "Homebrew" \
      "Could not create a temporary installer file." \
      "Restart the Mac and rerun this setup."
  }

  if ! curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
    rm -f "$installer"
    stop_setup \
      "Homebrew" \
      "Could not download the Homebrew installer." \
      "Check Wi-Fi, VPN, firewall, or content-filter settings, then rerun this setup."
  fi

  # Force the normal interactive Homebrew behavior. An inherited NONINTERACTIVE
  # or CI variable would otherwise suppress the password prompt.
  if ! (
    unset NONINTERACTIVE CI INTERACTIVE
    /bin/bash "$installer"
  ); then
    rm -f "$installer"
    echo ""
    stop_setup \
      "Homebrew" \
      "Homebrew did not finish installing." \
      "Read the Homebrew error immediately above, fix that issue, and rerun this setup."
  fi

  rm -f "$installer"
  load_brew_path || true
  persist_brew_path || stop_setup \
    "Shell profile" \
    "Homebrew installed, but its PATH could not be saved to your shell profile." \
    "Check ownership and write access for .zprofile/.bash_profile, then rerun setup."

  if ! command -v brew >/dev/null 2>&1; then
    stop_setup \
      "Homebrew" \
      "Homebrew finished, but the 'brew' command could not be found." \
      "Close Terminal, open it again, and rerun this setup."
  fi

  ok "Homebrew installed."
}

install_brew_formula() {
  local formula="$1"
  local name="$2"

  step "Installing $name"

  if brew list --formula "$formula" >/dev/null 2>&1; then
    ok "$name is already installed."
    record OK "$name"
    return 0
  fi

  if brew install "$formula"; then
    ok "$name installed."
    record OK "$name"
    return 0
  fi

  fail "Could not install $name with Homebrew formula '$formula'."
  record FAIL "$name"
  return 1
}

install_first_available_cask() {
  local name="$1"
  local fallback_url="$2"
  local cask
  shift 2

  step "Installing $name"
  note "This downloads a full application and can take several minutes."

  for cask in "$@"; do
    if brew list --cask "$cask" >/dev/null 2>&1; then
      ok "$name is already installed."
      record OK "$name"
      return 0
    fi
  done

  for cask in "$@"; do
    if brew install --cask "$cask"; then
      ok "$name installed."
      record OK "$name"
      return 0
    fi
    warn "Homebrew cask '$cask' did not install."
  done

  warn "$name was not installed. Opening its official download page instead."
  record FAIL "$name (manual installation needed)"
  open "$fallback_url" >/dev/null 2>&1 || true
  return 1
}

install_claude_code() {
  local installer

  step "Installing Claude Code"
  if ! ensure_tool_path; then
    fail "Claude Code PATH could not be saved to your shell profile."
    record FAIL "Claude Code PATH"
    return 1
  fi

  if command -v claude >/dev/null 2>&1 && claude --version >/dev/null 2>&1; then
    ok "Claude Code is already installed."
    record OK "Claude Code"
    return 0
  elif command -v claude >/dev/null 2>&1; then
    warn "A Claude Code command exists but did not pass verification; attempting repair."
  fi

  note "Trying Anthropic's recommended native installer first."
  installer="$(mktemp "${TMPDIR:-/tmp}/foad-claude.XXXXXX")" || installer=""

  if [[ -n "$installer" ]] && \
     curl -fsSL https://claude.ai/install.sh -o "$installer" && \
     /bin/bash "$installer"; then
    rm -f "$installer"
    if ! ensure_tool_path; then
      fail "Claude Code installed, but its PATH could not be saved."
      record FAIL "Claude Code PATH"
      return 1
    fi
    hash -r 2>/dev/null || true

    if command -v claude >/dev/null 2>&1 && claude --version >/dev/null 2>&1; then
      ok "Claude Code installed with the native installer."
      record OK "Claude Code"
      return 0
    fi

    warn "The native installer finished, but the 'claude' command is not available yet."
  else
    [[ -n "$installer" ]] && rm -f "$installer"
    warn "Claude Code's native installer did not finish."
  fi

  warn "Trying the official Homebrew cask instead."
  if brew install --cask claude-code && claude --version >/dev/null 2>&1; then
    hash -r 2>/dev/null || true
    ok "Claude Code installed with Homebrew."
    record OK "Claude Code (Homebrew)"
    return 0
  fi

  warn "Trying the npm fallback."
  if command -v npm >/dev/null 2>&1 && \
     npm install -g @anthropic-ai/claude-code && \
     claude --version >/dev/null 2>&1; then
    hash -r 2>/dev/null || true
    ok "Claude Code installed with npm."
    record OK "Claude Code (npm)"
    return 0
  fi

  fail "Claude Code could not be installed automatically."
  echo "Manual instructions: https://code.claude.com/docs/en/setup"
  record FAIL "Claude Code"
  return 1
}

write_claude_starter_files() {
  local skill_dir="$HOME/.claude/skills/summarize-changes"
  local command_dir="$HOME/.claude/commands"

  step "Creating Claude Code starter skill and command"

  if ! mkdir -p "$skill_dir"; then
    fail "Could not create Claude skill folder: $skill_dir"
    record FAIL "Claude starter files"
    return 1
  fi
  if [[ -f "$skill_dir/SKILL.md" ]]; then
    ok "Keeping existing file: $skill_dir/SKILL.md"
  else
    if ! cat > "$skill_dir/SKILL.md" <<'SKILL_EOF'
---
name: summarize-changes
description: Review the current Git working tree and summarize changed files, risks, and suggested tests before committing.
---

# Summarize Changes

Use this skill when the user wants to review current uncommitted Git changes before committing or pushing.

## Instructions

1. Run `git status --short` to see changed files.
2. Run `git diff --stat` to summarize the size of the changes.
3. Run `git diff` to inspect the actual changes when useful.
4. Summarize the work in 2-3 short bullets.
5. List possible bugs, missing tests, risky changes, security concerns, unclear code, and breaking changes.
6. If there are no changes, say the working tree is clean.
SKILL_EOF
    then
      fail "Could not write $skill_dir/SKILL.md"
      record FAIL "Claude starter files"
      return 1
    fi
  fi

  if ! mkdir -p "$command_dir"; then
    fail "Could not create Claude command folder: $command_dir"
    record FAIL "Claude starter files"
    return 1
  fi
  if [[ -f "$command_dir/summarize-changes.md" ]]; then
    ok "Keeping existing file: $command_dir/summarize-changes.md"
  else
    if ! cat > "$command_dir/summarize-changes.md" <<'COMMAND_EOF'
Review my current Git working tree before I commit.

Please run:
- git status --short
- git diff --stat
- git diff

Then summarize:
1. What changed in 2-3 bullets
2. Main correctness risks
3. Missing tests
4. Any security or breaking-change concerns
5. A short recommended commit message

If there are no changes, say the working tree is clean.
COMMAND_EOF
    then
      fail "Could not write $command_dir/summarize-changes.md"
      record FAIL "Claude starter files"
      return 1
    fi
  fi

  ok "Claude starter files are ready."
  record OK "Claude starter skill + /summarize-changes command"
}

write_terminal_guide() {
  local desktop="$HOME/Desktop"
  local guide="$desktop/FOAD-terminal-basics.txt"

  step "Creating beginner terminal guide"
  if ! mkdir -p "$desktop"; then
    fail "Could not access the Desktop folder: $desktop"
    record FAIL "Beginner guide on Desktop"
    return 1
  fi

  if [[ -f "$guide" ]]; then
    ok "Keeping existing guide: $guide"
    record OK "Beginner guide on Desktop"
    return 0
  fi

  if ! cat > "$guide" <<'GUIDE_EOF'
FOAD Terminal Basics - macOS

FIRST CHECKS
Run these after installation:

git --version
node --version
npm --version
python3 --version
claude --version

If a command is not found, close Terminal, open it again, and retry.
For Claude Code installation or login problems, run:

claude doctor

BASIC COMMANDS
pwd                     Show the current folder
ls                      List files
cd folder-name          Move into a folder
cd ..                   Move back one folder
mkdir my-project        Create a folder
open .                  Open the current folder in Finder
clear                   Clear the Terminal screen

GIT BASICS
git clone REPO_URL      Download a project
git status              See changed files
git add .               Stage all changes
git commit -m "message" Save a commit

Before your first commit, Git may ask for your name and email. Set them with:

git config --global user.name "Your Name"
git config --global user.email "you@example.com"

NODE BASICS
npm install             Install project packages
npm run dev             Start many web projects

PYTHON BASICS
python3 --version             Check Python
python3 -m venv .venv         Create a project environment
source .venv/bin/activate     Activate it
python -m pip install requests Install a package inside it
deactivate                    Leave the environment

CLAUDE CODE
claude                  Start Claude Code
claude doctor           Diagnose installation or login problems
/login                  Log in while inside Claude Code
/help                   Show help
/init                   Analyze a project and create CLAUDE.md
/skills                 Show available skills, if supported
/summarize-changes      Run FOAD's starter review command

Claude Code requires a supported paid plan, Console account, or supported
third-party provider. The free Claude.ai plan does not include Claude Code.

ANTIGRAVITY IDE
Open Google Antigravity IDE from Applications.
Sign in with a Google account on first launch.

KEEPING THINGS UP TO DATE
brew update && brew upgrade    Update Homebrew software
brew upgrade --cask claude-code Update Claude Code if installed with Homebrew

A native Claude Code installation updates itself automatically.

GETTING UNSTUCK
- Copy the complete error message, including a few lines above it.
- Paste it into Claude or show it to the workshop instructor.
- A password prompt shows no characters while you type. This is normal.
- "command not found" often means Terminal needs to be reopened once.
- Re-running preserves existing workshop files and skips detected packages.

FIRST TEST PROJECT
mkdir foad-test
cd foad-test
git init
echo hello > README.md
claude
GUIDE_EOF
  then
    fail "Could not write the beginner guide: $guide"
    record FAIL "Beginner guide on Desktop"
    return 1
  fi

  ok "Wrote guide to: $guide"
  record OK "Beginner guide on Desktop"
}

check_command_version() {
  local command="$1"
  local display_name="$2"
  local arg="${3:---version}"
  local output
  local status

  if command -v "$command" >/dev/null 2>&1; then
    output="$("$command" "$arg" 2>&1)"
    status=$?
    output="$(printf '%s\n' "$output" | head -n 1)"
    if [[ $status -eq 0 ]]; then
      ok "$display_name works: $output"
      return 0
    fi
    warn "$display_name was found, but its version check failed (exit $status): $output"
    record FAIL "$display_name verification"
    return 1
  fi

  warn "$display_name is not available in this Terminal session."
  record FAIL "$display_name verification (reopen Terminal and retry)"
  return 1
}

# ---------- Start ----------
printf '%s' "$C_BOLD"
cat <<'BANNER'

  ______ ____          _____
 |  ____/ __ \   /\   |  __ \
 | |__ | |  | | /  \  | |  | |
 |  __|| |  | |/ /\ \ | |  | |
 | |   | |__| / ____ \| |__| |
 |_|    \____/_/    \_\_____/   Dev Setup - macOS

BANNER
printf '%s' "$C_RESET"

printf 'Installer version: %s\n' "$SCRIPT_VERSION"
echo "This installs Homebrew, Git, Node.js/npm, Python 3, Google Antigravity IDE,"
echo "Claude Code, and FOAD starter files. A new Mac commonly takes 10-25 minutes."
echo "Homebrew may ask for your Mac password and permission to install developer tools."
note "Reruns preserve existing workshop files and skip detected packages."

if [[ "${FOAD_ASSUME_YES:-0}" != "1" ]]; then
  echo ""
  echo "Before continuing:"
  echo "- Allow 10-25 minutes and several gigabytes of free disk space."
  echo "- Homebrew may request administrator approval."
  echo "- Claude Code needs an eligible Claude subscription, Console account, or supported provider."
  echo "- Antigravity IDE sign-in may require a Google account."
  echo "- This setup adds PATH lines to .zprofile/.bash_profile and creates files under ~/.claude and Desktop."
  printf 'Press Enter to continue, or type q then Enter to cancel: '
  read -r consent
  if [[ "$consent" == "q" || "$consent" == "Q" ]]; then
    echo "Setup cancelled. No installation steps were started."
    exit 0
  fi
fi

step "Checking your Mac and internet connection"

if [[ "$(uname -s 2>/dev/null || echo unknown)" != "Darwin" ]]; then
  stop_setup \
    "Operating system" \
    "This installer only works on macOS." \
    "Run it from a Mac using Apple's Terminal app."
fi

if [[ "$(id -u)" == "0" ]]; then
  stop_setup \
    "User account" \
    "Do not run this setup with 'sudo'. Homebrew must be installed from your normal Mac account." \
    "Close this Terminal window, open Terminal normally, and rerun the setup command without 'sudo'."
fi

os_version="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
os_major="${os_version%%.*}"

if ! [[ "$os_major" =~ ^[0-9]+$ ]]; then
  stop_setup \
    "macOS version" \
    "Could not determine the macOS version." \
    "Restart the Mac, open Terminal, and rerun this setup."
elif (( os_major < 14 )); then
  stop_setup \
    "macOS version" \
    "macOS $os_version is not supported by this Homebrew-based setup." \
    "Update macOS to version 14 or newer, then rerun this setup."
else
  ok "macOS $os_version detected."
  record OK "macOS $os_version"
fi

if curl -fsSL --connect-timeout 10 --max-time 20 \
  https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
  -o /dev/null; then
  ok "Internet connection works."
  record OK "Internet connection"
else
  stop_setup \
    "Internet connection" \
    "The setup could not reach GitHub." \
    "Check Wi-Fi, VPN, firewall, or content-filter settings, then rerun this setup."
fi

step "Checking Homebrew"

# A previous installation may exist in its standard location even if this shell
# has not loaded Homebrew's PATH yet.
load_brew_path || true

if command -v brew >/dev/null 2>&1; then
  ok "Homebrew is already installed."
else
  install_homebrew
fi

load_brew_path || true
persist_brew_path || stop_setup \
  "Shell profile" \
  "Homebrew is available now, but its PATH could not be saved to your shell profile." \
  "Check ownership and write access for .zprofile/.bash_profile, then rerun setup."
ensure_tool_path || stop_setup \
  "Shell profile" \
  "Tool paths could not be saved to your shell profile." \
  "Check ownership and write access for .zprofile/.bash_profile, then rerun setup."

if ! command -v brew >/dev/null 2>&1; then
  stop_setup \
    "Homebrew" \
    "The 'brew' command is still unavailable." \
    "Close Terminal, open it again, and rerun this setup."
fi
record OK "Homebrew"

step "Updating Homebrew package information"
note "This can take a minute on the first run."
if brew update; then
  ok "Homebrew package information is current."
  record OK "Homebrew package information"
else
  warn "Homebrew could not refresh its package information. Continuing with available information."
  record WARN "Homebrew package information (update failed)"
fi

install_brew_formula "git" "Git" || true
install_brew_formula "node" "Node.js + npm" || true
install_brew_formula "python" "Python 3 + pip" || true

install_first_available_cask \
  "Google Antigravity IDE" \
  "https://antigravity.google/download" \
  "antigravity-ide" || true

install_claude_code || true
write_claude_starter_files || true
write_terminal_guide || true

step "Verifying installed commands"
load_brew_path || true
if ! ensure_tool_path; then
  fail "Tool paths could not be saved to your shell profile."
  record FAIL "Shell profile PATH"
fi
hash -r 2>/dev/null || true

check_command_version git "Git" || true
check_command_version node "Node.js" || true
check_command_version npm "npm" || true
check_command_version python3 "Python 3" || true
check_command_version pip3 "pip3" || true
check_command_version claude "Claude Code" || true

print_summary

printf '\n%s=== Next steps ===%s\n' "$C_BOLD" "$C_RESET"

if results_have_state FAIL; then
  echo "1. Fix the items marked ✘ in the summary above."
  echo "2. Rerun this setup. Installed items will be skipped."
  echo "3. Share the complete error output with the workshop instructor if it still fails."
else
  echo "1. Close this Terminal window and open a new one once."
  echo "2. Run: claude"
  echo "3. Follow the browser login instructions."
  echo "4. Open Google Antigravity IDE from Applications and sign in."
  echo "5. Read FOAD-terminal-basics.txt on your Desktop."
fi

echo ""

if [[ -f "$HOME/Desktop/FOAD-terminal-basics.txt" ]]; then
  open -e "$HOME/Desktop/FOAD-terminal-basics.txt" >/dev/null 2>&1 || true
fi

if results_have_state FAIL; then
  fail "FOAD setup finished with one or more failed items."
  exit 1
fi

if results_have_state WARN; then
  warn "FOAD setup finished with warnings. Review the summary above."
  exit 0
fi

ok "FOAD setup finished successfully."
exit 0
