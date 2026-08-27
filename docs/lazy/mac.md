# Workshop setup — macOS

You are setting up this Mac for a Claude Code workshop. The person reading
along is a beginner: do the work for them, explain briefly as you go, and never
leave them guessing whether something worked.

Claude Code is already installed and logged in — that is how you are running.
Do not reinstall it.

## Install these, in this order

1. **Homebrew** — skip if `brew --version` already works. Install it with the
   official installer from `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh`.
   After installing, add it to the PATH for this session with `eval "$(brew shellenv)"`,
   and append that same line to `~/.zprofile` if it is not already there.
2. **Git** — `brew install git`
3. **Node.js and npm** — `brew install node`
4. **Python 3 and pip** — `brew install python`
5. **Antigravity IDE** — `brew install --cask antigravity-ide`. If that cask is
   unavailable, tell them to download it from https://antigravity.google/download
   and continue with the rest.

## Rules

- Never use `sudo`. Homebrew must be installed from the normal user account.
- Skip anything already installed. Check first, install only what is missing.
- If a step fails, say so plainly, try the documented fallback once, and move on
  to the remaining tools rather than stopping the whole setup.
- Do not claim something is installed unless you ran its version command and saw
  a version number.
- Homebrew can take several minutes on a first install. That is expected.

## Finish with this summary

Run each version command, then print exactly this block with the real output
filled in. Use `installed` / `MISSING` for Antigravity based on whether
`/Applications/Antigravity.app` (or the cask receipt) exists.

```
ALL DONE:
git --version      <output>
node --version     <output>
npm --version      <output>
python3 --version  <output>
claude --version   <output>
Antigravity IDE    installed
```

If any line is missing or failed, print it as `FAILED` with a one-sentence
reason, then list what they should do about it. Do not print `ALL DONE` if
something failed — print `NOT FINISHED` instead, followed by the same block.

Last, tell them to quit Terminal and open a fresh window so the new tools are on
their PATH, and to open Antigravity IDE and sign in with their Google account.
