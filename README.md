# opskit

[![CI](https://github.com/0xDiyor/opskit/actions/workflows/ci.yml/badge.svg)](https://github.com/0xDiyor/opskit/actions/workflows/ci.yml)

Terminal based IT diagnostics toolkit for Windows. Network, ports, health, and cert checks plus vetted script execution, with a modular design built to grow. Zero dependencies, PowerShell 5.1 compatible.

<!-- Add a terminal screenshot here once the menu renders: docs/screenshots/menu.png -->
<!-- ![opskit menu](docs/screenshots/menu.png) -->

## Why

Helpdesk and sysadmin work means running the same handful of diagnostics dozens of times a week: what process owns this port, is DNS resolving, when does this cert expire, why is this machine slow. opskit puts those checks behind one menu, in pure PowerShell, so it runs on any stock Windows box with nothing to install.

## Requirements

- Windows PowerShell 5.1 (ships with Windows 10/11) or PowerShell 7+
- No modules, no dependencies, nothing to install

## Quick start

```powershell
git clone https://github.com/0xDiyor/opskit.git
cd opskit
powershell -ExecutionPolicy Bypass -File .\opskit.ps1
```

The `-ExecutionPolicy Bypass` flag is needed because PowerShell 5.1 blocks unsigned scripts by default. Review the source first; that is the whole point of the policy.

## Features

| Module | Status | What it does |
|---|---|---|
| Ports in use | Working | Maps listening ports to owning processes (port, address, PID, process name) |
| Network toolkit | Working | Subnet/CIDR math, DNS record lookups, latency and traceroute diagnostics |
| System health snapshot | Working | CPU, RAM, disk, uptime, and top processes, with optional text export for ticket notes |
| Certificate checker | Working | Remote cert inspection (expiry, chain status) and local store expiry scan with warning thresholds |
| Script runner | Planned | Runs vetted scripts from the local `scripts/` folder only |

There is also an in-app help screen (`H` from the main menu) covering navigation and each module's expected input.

## Security design

The script runner is intentionally restricted:

- Only lists and executes `.ps1` files from the repo's own `scripts/` folder. No path input, no arbitrary execution.
- Shows the script's synopsis and asks for confirmation before running.
- Planned: SHA256 hash allowlisting via a manifest, so tampered or unapproved scripts are refused even if placed in the folder.

If you run this tool in a managed environment, get approval from whoever owns that environment first.

## Design notes

- Menu, dispatch table, function, pause, back to menu. Adding a feature means writing one function and adding one dispatch entry.
- ASCII only output and 16 color `Write-Host` for compatibility with stock conhost on 5.1. No ANSI escape codes, no Unicode box drawing.
- Modules live in `modules/` and are dot sourced by the entry script as the project grows.

## Roadmap

- [x] v0.1: menu shell plus working ports module
- [x] v0.2: health snapshot and network toolkit (subnet calc, DNS, traceroute)
- [x] v0.3: cert checker (remote and local store)
- [ ] v0.4: folder scoped script runner with hash verified manifest
- [ ] v0.5: non-interactive mode (run a module straight from the command line)

## CI

Every push and pull request runs through GitHub Actions on a `windows-latest` runner ([ci.yml](.github/workflows/ci.yml)):

- **Lint**: PSScriptAnalyzer over the whole repo, failing on any warning or error. Rule config lives in [PSScriptAnalyzerSettings.psd1](PSScriptAnalyzerSettings.psd1) (only `PSAvoidUsingWriteHost` is excluded - colored host output is the point of a TUI).
- **Smoke test**: [tests/smoke.ps1](tests/smoke.ps1) drives every implemented module end to end through the real menu under Windows PowerShell 5.1 (the compatibility floor), by feeding menu choices via stdin and asserting on each module's output. This exercises the Windows-only paths - `Get-NetTCPConnection`, `Get-CimInstance`, `Resolve-DnsName`, the `Cert:` drive - on every change.

To support running headless in CI, the script guards its console calls: `Clear-Host` is skipped and `RawUI.ReadKey` falls back to `Read-Host` when the console handles are redirected. A side benefit is that opskit now behaves sanely when its output is piped to a file.

## Contributing

Issues and PRs welcome. CI must pass: PSScriptAnalyzer with the repo settings file plus the smoke test (see above). To check locally before pushing:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
.\tests\smoke.ps1
```

## License

MIT. See [LICENSE](LICENSE).
