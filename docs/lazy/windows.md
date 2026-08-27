# Workshop setup — Windows

You are setting up this Windows PC for a Claude Code workshop. The person
reading along is a beginner: do the work for them, explain briefly as you go,
and never leave them guessing whether something worked.

Claude Code is already installed and logged in — that is how you are running.
Do not reinstall it.

Everything here runs in Windows PowerShell. Do not use WSL or a Linux shell for
any of it, even if one is available.

## Install these, in this order

1. **Check WinGet** — run `winget --version`. If it is missing, tell them to
   install **App Installer** from https://apps.microsoft.com/detail/9nblggh4nns1
   and to run you again afterwards; without WinGet you cannot continue.
2. **Git** — `winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements`
3. **Node.js and npm** — `winget install --id OpenJS.NodeJS.LTS --exact --source winget --accept-package-agreements --accept-source-agreements`
4. **Antigravity IDE** — `winget install --id Google.AntigravityIDE --exact --source winget --accept-package-agreements --accept-source-agreements`.
   The ID must end in `IDE`; `Google.Antigravity` is a different application and
   is not what the workshop uses. This is a large download and can look frozen
   for several minutes. If it fails, tell them to download it from
   https://antigravity.google/download and continue with the rest.
5. **Python 3 and pip** — try `Python.Python.3.14`, then `3.13`, then `3.12`,
   with the same WinGet flags. Stop at the first that succeeds. If all fail, tell
   them to install from https://www.python.org/downloads/windows/ and to tick
   **Add python.exe to PATH**.

## Rules

- Skip anything already installed. Check first, install only what is missing.
- A Windows permission box may appear behind other windows. If a command seems
  to hang, tell them to check the taskbar for it.
- After the installs, refresh PATH for this session from the machine and user
  environment variables so the version checks below can find the new tools.
- If a step fails, say so plainly, try the documented fallback once, and move on
  to the remaining tools rather than stopping the whole setup.
- Do not claim something is installed unless you ran its version command and saw
  a version number.

## Finish with this summary

Run each version command, then print exactly this block with the real output
filled in. For Python, fall back to `py --version` if `python --version` opens
the Microsoft Store or prints nothing. Use `installed` / `MISSING` for
Antigravity based on whether WinGet lists `Google.AntigravityIDE`.

```
ALL DONE:
git --version      <output>
node --version     <output>
npm --version      <output>
python --version   <output>
claude --version   <output>
Antigravity IDE    installed
```

If any line is missing or failed, print it as `FAILED` with a one-sentence
reason, then list what they should do about it. Do not print `ALL DONE` if
something failed — print `NOT FINISHED` instead, followed by the same block.

Last, tell them to close PowerShell and open a fresh window so the new tools are
on their PATH, and to open **Antigravity IDE** from the Start Menu and sign in
with their Google account. If Antigravity offers to install WSL, they should
choose Skip or Cancel, and pick the PowerShell profile in its terminal.
