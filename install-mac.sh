#!/usr/bin/env bash
# FOAD Dev Setup - macOS
# Installs: Homebrew, Git, Node.js/npm, Google Antigravity IDE, Claude Code, and beginner Claude Code skill files.
# Safe to re-run.
# Website command:
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/masterFoad/agent_setup/main/install-mac.sh)"

set -u

step() { printf '\n=== %s ===\n' "$1"; }
ok() { printf '[OK] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; }

append_once() {
  local file="$1"
  local line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fqx "$line" "$file" 2>/dev/null; then
    printf '\n%s\n' "$line" >> "$file"
  fi
}

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
  else
    if brew install "$formula"; then
      ok "$name installed."
    else
      warn "Could not install $name with Homebrew formula: $formula"
      return 1
    fi
  fi
}

install_first_available_cask() {
  local name="$1"
  shift
  step "Installing $name"

  for cask in "$@"; do
    if brew list --cask "$cask" >/dev/null 2>&1; then
      ok "$name is already installed as cask '$cask'."
      return 0
    fi
  done

  for cask in "$@"; do
    if brew install --cask "$cask"; then
      ok "$name installed with cask '$cask'."
      return 0
    else
      warn "Could not install $name with cask '$cask'. Trying next option if available."
    fi
  done

  warn "$name was not installed from Homebrew. Opening the official download page as a fallback."
  open "https://antigravity.google/download" >/dev/null 2>&1 || true
  return 1
}

install_claude_code() {
  step "Installing Claude Code"
  ensure_path_line

  if command -v claude >/dev/null 2>&1; then
    ok "Claude Code is already available."
    return 0
  fi

  if curl -fsSL https://claude.ai/install.sh | bash; then
    ensure_path_line
    ok "Claude Code installer finished."
    return 0
  fi

  warn "Claude Code native installer failed. Trying npm fallback: npm install -g @anthropic-ai/claude-code"
  if command -v npm >/dev/null 2>&1 && npm install -g @anthropic-ai/claude-code; then
    ok "Claude Code installed with npm fallback."
    return 0
  fi

  warn "Claude Code install failed. Install manually from: https://code.claude.com/docs/en/setup"
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
claude --version

If a command is not found, close Terminal, open it again, and retry.

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

CLAUDE CODE
claude                  Start Claude Code
/login                  Login or register when inside Claude Code
/help                   Show Claude Code help
/skills                 Show available skills, if supported
/summarize-changes      Run FOAD's starter review command

ANTIGRAVITY IDE
Open Google Antigravity IDE from Applications.

FIRST TEST PROJECT
mkdir foad-test
cd foad-test
git init
echo hello > README.md
claude
GUIDE_EOF

  ok "Wrote guide to: $desktop/FOAD-terminal-basics.txt"
}

check_command_version() {
  local command="$1"
  local arg="${2:---version}"
  if command -v "$command" >/dev/null 2>&1; then
    local output
    output="$($command $arg 2>&1 | head -n 1 || true)"
    ok "$command works: $output"
  else
    warn "$command is not available yet. Restart Terminal and try: $command $arg"
  fi
}

step "FOAD Dev Setup for macOS"
echo "This installs Homebrew, Git, Node.js/npm, Antigravity IDE, Claude Code, and FOAD starter Claude files."
echo "Homebrew may ask for your Mac password. That is normal."

step "Checking Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    warn "Homebrew install failed. Install Homebrew manually from https://brew.sh and rerun this script."
    exit 1
  }
fi

load_and_persist_brew_path
ensure_path_line

if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew was installed but is not on PATH yet. Close and reopen Terminal, then rerun this script."
  exit 1
fi

step "Updating Homebrew"
brew update || warn "brew update failed; continuing with existing package index."

install_brew_formula "git" "Git" || true
install_brew_formula "node" "Node.js + npm" || true
install_first_available_cask "Google Antigravity IDE" "antigravity-ide" || true
install_claude_code || true
write_claude_starter_files
write_terminal_guide

step "Verifying installs"
check_command_version git
check_command_version node
check_command_version npm
check_command_version claude

step "Next steps"
echo "1. Close and reopen Terminal."
echo "2. Run: claude"
echo "3. Inside Claude Code, login/register if asked. You can also type: /login"
echo "4. Open Google Antigravity IDE from Applications."
echo "5. Read the desktop file: FOAD-terminal-basics.txt"
echo ""
ok "FOAD setup finished. If one check warned, restart Terminal and rerun this script. It is safe to re-run."
