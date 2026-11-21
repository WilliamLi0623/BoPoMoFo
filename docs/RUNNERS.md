# Self-hosted runners

The repository runs Linux and Android CI on a self-hosted Linux runner
(`bopomofo-linux`), and Windows builds on a self-hosted Windows runner
(`bopomofo-windows`). `windows-latest`/`macos-latest` hosted jobs are blocked
by the account's GitHub Actions spending limit; fix Billing & plans to use
them again.

## Linux runner (`bopomofo-linux`)

Registered as a Windows-independent service on the homelab Linux box. No
extra PATH requirements; the workflows install their own apt dependencies.

## Windows runner (`bopomofo-windows`)

Registered name `LAPTOP-EA5F91JJ`, working directory `C:\actions-runner`.

Requirements **before starting `run.cmd`** (the runner inherits the shell's
PATH):

- **Git Bash first on PATH.** `subosito/flutter-action@v2` is a composite
  action whose steps use `shell: bash`. If plain `bash` resolves to the
  `WindowsApps` WSL proxy, setup fails within seconds (`RUNNER_OS: unbound
  variable`, missing `jq`). Prefix Git Bash:
  `$env:Path = 'C:\Program Files\Git\bin;C:\Program Files\Git\usr\bin;' + $env:Path`
- **`jq` on PATH.** `setup.sh` needs it. A copy lives at
  `C:\actions-runner\jq.exe`, so the startup line also prepends
  `C:\actions-runner`.

Full startup line used for the interactive runner:

```powershell
$env:Path = 'C:\Program Files\Git\bin;C:\Program Files\Git\usr\bin;C:\actions-runner;' + $env:Path
Set-Location 'C:\actions-runner'
.\run.cmd
```

The runner currently runs interactively (a console window). To make it a
Windows service instead (survives sign-out, needs an elevated prompt once):

```powershell
Set-Location 'C:\actions-runner'
.\svc install    # requires admin
.\svc start
```

VS Build Tools 2022 is installed for the Windows desktop builds; the
`flutter-action` installs its own Flutter SDK under `C:\actions-runner\_work\_tool`.
