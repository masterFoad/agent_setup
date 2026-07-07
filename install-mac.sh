#!/usr/bin/env bash
# FOAD Dev Setup - macOS
# Installs: Homebrew, Git, Node.js/npm, Python 3, Google Antigravity IDE, Claude Code,
# and beginner Claude Code skill files. Safe to re-run.
# Website command:
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/masterFoad/agent_setup/main/install-mac.sh)"
#
# WORKSHOP INSTRUCTOR NOTES:
# - Ask attendees to run this BEFORE the workshop if possible (downloads are ~1 GB total;
#   30 people on venue Wi-Fi at once will be slow).
# - Attendees need: macOS 12+, their Mac login password (admin), and a Google account
#   for Antigravity. Claude Code needs a paid Claude plan (Pro+) or API account.
# - On a fresh Mac, Homebrew first installs Apple's Command Line Tools (5-15 min,
#   looks frozen — it is not). The script warns attendees about this.
# - Written for macOS's built-in /bin/bash 3.2 — do not add bash 4+ features.

set -u

# ---------- Pretty output (colors only when in a real terminal) ----------
if [[ -t 1 ]]; then
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
  C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""; C_DIM=""; C_RESET=""
fi

TOTAL_STEPS=11
STEP_NUM=0

step() {
  STEP_NUM=$((STEP_NUM + 1))
  printf '\n%s=== [%d/%d] %s ===%s\n' "$C_BOLD" "$STEP_NUM" "$TOTAL_STEPS" "$1" "$C_RESET"
}
ok()   { printf '%s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$1"; }
fail() { printf '%s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$1"; }
note() { printf '%s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }

# ---------- Result tracking for the final summary ----------
RESULT_NAMES=()
RESULT_STATES=()
record() { # record <state: OK|WARN|FAIL> <name>
  RESULT_STATES+=("$1")
  RESULT_NAMES+=("$2")
}

print_summary() {
  # Guard: expanding an empty array errors under `set -u` on macOS's bash 3.2.
  if [[ ${#RESULT_NAMES[@]} -eq 0 ]]; then
    return 0
  fi
  printf '\n%s=== Setup summary ===%s\n' "$C_BOLD" "$C_RESET"
  local i had_fail=0
  for i in "${!RESULT_NAMES[@]}"; do
    case "${RESULT_STATES[$i]}" in
      OK)   printf '  %s✔%s %s\n' "$C_GREEN" "$C_RESET" "${RESULT_NAMES[$i]}" ;;
      WARN) printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "${RESULT_NAMES[$i]}"; had_fail=1 ;;
      FAIL) printf '  %s✘%s %s\n' "$C_RED" "$C_RESET" "${RESULT_NAMES[$i]}"; had_fail=1 ;;
    esac
  done
  if [[ $had_fail -eq 1 ]]; then
    printf '\n%sSome items need attention. Close and reopen Terminal, then rerun this script — it is safe to re-run.%s\n' "$C_YELLOW" "$C_RESET"
  else
    printf '\n%s🎉 Everything installed successfully!%s\n' "$C_GREEN$C_BOLD" "$C_RESET"
  fi
}

on_interrupt() {
  printf '\n\n%sSetup was interrupted.%s Nothing is broken — rerun the script any time to continue where it left off.\n' "$C_YELLOW" "$C_RESET"
  exit 130
}
trap on_interrupt INT

# ---------- Helpers ----------
append_once() {
  local file="$1"
  local line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fqx "$line" "$file" 2>/dev/null; then
    printf '\n%s\n' "$line" >> "$file"
  fi
}

# shellcheck disable=SC2016  # lines below must be written literally to shell profiles
load_and_persist_brew_path() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    append_once "$HOME/.zprofile" 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    append_once "$HOME/.bash_profile" 'eval "$(/opt/homebrew/bin/brew shellenv)"'
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    append_once "$HOME/.zprofile" 'eval "$(/usr/local/bin/brew shellenv)"'
    append_once "$HOME/.bash_profile" 'eval "$(/usr/local/bin/brew shellenv)"'
  fi
}

# shellcheck disable=SC2016  # PATH line must be written literally so it expands at shell startup
ensure_path_line() {
  append_once "$HOME/.zprofile" 'export PATH="$HOME/.local/bin:$HOME/.claude/bin:$HOME/.claude/local:$PATH"'
  append_once "$HOME/.bash_profile" 'export PATH="$HOME/.local/bin:$HOME/.claude/bin:$HOME/.claude/local:$PATH"'
  export PATH="$HOME/.local/bin:$HOME/.claude/bin:$HOME/.claude/local:$PATH"
}

install_brew_formula() {
  local formula="$1"
  local name="$2"
  step "Installing $name"
  if brew list --formula "$formula" >/dev/null 2>&1; then
    ok "$name is already installed."
    record OK "$name"
  else
    if brew install "$formula"; then
      ok "$name installed."
      record OK "$name"
    else
      warn "Could not install $name with Homebrew formula: $formula"
      record FAIL "$name"
      return 1
    fi
  fi
}

install_first_available_cask() {
  local name="$1"
  shift
  step "Installing $name"
  note "This downloads a full app and can take a few minutes. The progress bar is normal."

  local cask
  for cask in "$@"; do
    if brew list --cask "$cask" >/dev/null 2>&1; then
      ok "$name is already installed as cask '$cask'."
      record OK "$name"
      return 0
    fi
  done

  for cask in "$@"; do
    if brew install --cask "$cask"; then
      ok "$name installed with cask '$cask'."
      record OK "$name"
      return 0
    else
      warn "Could not install $name with cask '$cask'. Trying next option if available."
    fi
  done

  warn "$name was not installed from Homebrew. Opening the official download page as a fallback."
  record WARN "$name (install manually from the page that just opened)"
  open "https://antigravity.google/download" >/dev/null 2>&1 || true
  return 1
}

install_claude_code() {
  step "Installing Claude Code"
  ensure_path_line

  if command -v claude >/dev/null 2>&1; then
    ok "Claude Code is already available."
    record OK "Claude Code"
    return 0
  fi

  # Native installer (recommended by Anthropic). Installs to ~/.local/bin and auto-updates.
  # Download first, then run: "curl | bash" would report success even if the download
  # failed (bash exits 0 on empty input), and could execute a partial download.
  local installer
  installer="$(mktemp "${TMPDIR:-/tmp}/claude-install.XXXXXX")"
  if curl -fsSL https://claude.ai/install.sh -o "$installer" && bash "$installer"; then
    rm -f "$installer"
    ensure_path_line
    ok "Claude Code installer finished."
    record OK "Claude Code"
    return 0
  fi
  rm -f "$installer"

  # Fallback 1: official Homebrew cask (stable channel; update later with: brew upgrade claude-code).
  warn "Claude Code native installer failed. Trying Homebrew cask: claude-code"
  if brew install --cask claude-code; then
    ok "Claude Code installed with Homebrew cask. Update later with: brew upgrade claude-code"
    record OK "Claude Code (via Homebrew)"
    return 0
  fi

  # Fallback 2: npm package (installs the same native binary; wants Node.js 22+,
  # older Node prints an EBADENGINE warning but still works).
  warn "Homebrew cask failed. Trying npm fallback: npm install -g @anthropic-ai/claude-code"
  if command -v npm >/dev/null 2>&1 && npm install -g @anthropic-ai/claude-code; then
    ok "Claude Code installed with npm fallback."
    record OK "Claude Code (via npm)"
    return 0
  fi

  fail "Claude Code install failed. Install manually from: https://code.claude.com/docs/en/setup"
  record FAIL "Claude Code"
  return 1
}

write_claude_starter_files() {
  step "Creating Claude Code starter skill and command"

  local skill_dir="$HOME/.claude/skills/summarize-changes"
  mkdir -p "$skill_dir"
  if [[ -f "$skill_dir/SKILL.md" ]]; then
    ok "Keeping existing file: $skill_dir/SKILL.md"
  else
    cat > "$skill_dir/SKILL.md" <<'SKILL_EOF'
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
  fi

  local command_dir="$HOME/.claude/commands"
  mkdir -p "$command_dir"
  if [[ -f "$command_dir/summarize-changes.md" ]]; then
    ok "Keeping existing file: $command_dir/summarize-changes.md"
  else
    cat > "$command_dir/summarize-changes.md" <<'COMMAND_EOF'
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
  fi

  ok "Claude starter files are ready."
  record OK "Claude starter skill + /summarize-changes command"
}

write_terminal_guide() {
  step "Creating beginner terminal guide"

  local desktop="$HOME/Desktop"
  mkdir -p "$desktop"

  cat > "$desktop/FOAD-terminal-basics.txt" <<'GUIDE_EOF'
FOAD Terminal Basics - macOS

FIRST CHECKS
Run these after install:

git --version
node --version
npm --version
python3 --version
claude --version

If a command is not found, close Terminal, open it again, and retry.
If Claude Code misbehaves, run: claude doctor
It checks your install, login, and configuration.

BASIC COMMANDS
pwd                     Show current folder
ls                      List files
cd folder-name          Move into a folder
cd ..                   Move back one folder
mkdir my-project        Create a folder
touch file.txt          Create a file
clear                   Clear the screen

GIT BASICS
git clone REPO_URL      Download a project
git status              See changed files
git add .               Stage all changes
git commit -m "message" Save a commit

NODE BASICS
npm install             Install project packages
npm run dev             Start many web projects

PYTHON BASICS
python3 --version       Check Python is installed
pip3 install requests   Install a Python package
python3 script.py       Run a Python script

CLAUDE CODE
claude                  Start Claude Code
claude doctor           Diagnose install or login problems
/login                  Login or register when inside Claude Code
/help                   Show Claude Code help
/init                   Let Claude analyze a project and create CLAUDE.md
/skills                 Show available skills, if supported
/summarize-changes      Run FOAD's starter review command

Note: Claude Code needs a paid Claude plan (Pro or higher) or an API account.
The free Claude.ai plan does not include Claude Code.

ANTIGRAVITY IDE
Open Google Antigravity IDE from Applications.
Sign in with a Google account on first launch.

KEEPING THINGS UP TO DATE
brew update && brew upgrade    Update everything installed with Homebrew
Claude Code (native install) updates itself automatically.

GETTING UNSTUCK
Copy any error message and paste it into Claude (claude.ai or Claude Code).
Screenshots of errors work too. This solves most beginner problems.

WORKSHOP TIPS
- "command not found"? Close Terminal, open a new one, try again.
- Something looks frozen? Downloads can be slow on shared Wi-Fi. Wait a bit.
- Still stuck? Ask the instructor - that is what workshops are for.
- You cannot break anything by re-running the setup script.

FIRST TEST PROJECT
mkdir foad-test
cd foad-test
git init
echo hello > README.md
claude
GUIDE_EOF

  ok "Wrote guide to: $desktop/FOAD-terminal-basics.txt"
  record OK "Beginner guide on Desktop"
}

check_command_version() {
  local command="$1"
  local arg="${2:---version}"
  if command -v "$command" >/dev/null 2>&1; then
    local output
    output="$("$command" "$arg" 2>&1 | head -n 1 || true)"
    ok "$command works: $output"
  else
    warn "$command is not available yet. Restart Terminal and try: $command $arg"
    record WARN "$command not on PATH yet (restart Terminal)"
  fi
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

echo "This installs: Homebrew, Git, Node.js/npm, Python 3, Google Antigravity IDE,"
echo "Claude Code, and FOAD starter files. It usually takes 5-15 minutes."
echo "Homebrew may ask for your Mac password. That is normal."
note "Safe to re-run: anything already installed is skipped."

step "Checking your Mac and internet connection"
os_version="$(sw_vers -productVersion 2>/dev/null || echo "unknown")"
os_major="${os_version%%.*}"
if [[ "$os_major" =~ ^[0-9]+$ ]] && (( os_major < 12 )); then
  warn "You are on macOS $os_version. Some apps (like Antigravity IDE) need macOS 12 or newer."
  record WARN "macOS version is old ($os_version)"
else
  ok "macOS $os_version detected."
fi

if curl -fsSL --max-time 15 --head https://github.com >/dev/null 2>&1; then
  ok "Internet connection works."
else
  fail "No internet connection detected. Connect to Wi-Fi and rerun this script."
  record FAIL "Internet connection"
  print_summary
  exit 1
fi

step "Checking Homebrew"
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew is already installed."
else
  echo "Homebrew not found. Installing Homebrew..."
  echo "macOS will ask for your password. Type your Mac login password and press Return."
  echo "The screen will NOT show characters as you type the password. That is normal."
  note "Heads up: on a brand-new Mac this also installs Apple's Command Line Tools."
  note "That part can take 5-15 minutes and may look stuck. It is not stuck — let it run."
  # NONINTERACTIVE=1 skips Homebrew's "Press RETURN to continue" confirmation so
  # beginners do not think the installer has frozen. The sudo password prompt
  # still appears (and must) because Homebrew needs it to create its directories.
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    fail "Homebrew install failed. Install Homebrew manually from https://brew.sh and rerun this script."
    record FAIL "Homebrew"
    print_summary
    exit 1
  }
fi

load_and_persist_brew_path
ensure_path_line

if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew was installed but is not on PATH yet. Close and reopen Terminal, then rerun this script."
  record WARN "Homebrew (restart Terminal, rerun script)"
  print_summary
  exit 1
fi
record OK "Homebrew"

step "Updating Homebrew package list"
note "This can take a minute on first run."
brew update || warn "brew update failed; continuing with existing package index."

install_brew_formula "git" "Git" || true
install_brew_formula "node" "Node.js + npm" || true
# Python 3 (+ pip): agents and Claude Code frequently shell out to it for scripts.
install_brew_formula "python" "Python 3 + pip" || true
# Cask "antigravity-ide" verified to exist in homebrew-cask (Google Antigravity IDE).
# Note: a separate "antigravity" cask (Antigravity 2 agent orchestration platform) also exists; not the IDE.
install_first_available_cask "Google Antigravity IDE" "antigravity-ide" || true
install_claude_code || true
write_claude_starter_files
write_terminal_guide

step "Verifying installs"
check_command_version git
check_command_version node
check_command_version npm
check_command_version python3
check_command_version pip3
check_command_version claude

print_summary

printf '\n%s=== Next steps ===%s\n' "$C_BOLD" "$C_RESET"
printf '1. %sClose this Terminal window and open a new one.%s (This is required — new commands\n' "$C_BOLD" "$C_RESET"
echo "   like 'claude' only work in a fresh Terminal.)"
echo "2. Run: claude"
echo "3. Inside Claude Code, login/register if asked. You can also type: /login"
echo "   (Claude Code needs a paid Claude plan or API account - the free plan is not enough.)"
echo "4. Open Google Antigravity IDE from Applications and sign in with a Google account."
echo "5. Read the guide that just opened: FOAD-terminal-basics.txt (also on your Desktop)."
echo ""
ok "FOAD setup finished. It is safe to re-run this script any time."

# Open the beginner guide so new users see it immediately.
open -e "$HOME/Desktop/FOAD-terminal-basics.txt" >/dev/null 2>&1 || true