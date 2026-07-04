# opskit

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
| Network toolkit | Planned | Subnet/CIDR math, DNS record lookups, latency and trace diagnostics |
| System health snapshot | Planned | CPU, RAM, disk, uptime, and top processes in one exportable view |
| Certificate checker | Planned | Remote and local cert expiry checks with warning thresholds |
| Script runner | Planned | Runs vetted scripts from the local `scripts/` folder only |

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

- v0.1: menu shell plus working ports module
- v0.2: health snapshot and DNS lookups
- v0.3: cert checker and folder scoped script runner
- v0.4: hash verified script manifest, ticket note export

## Contributing

Issues and PRs welcome. Code is linted with PSScriptAnalyzer; run it before submitting.

## License

MIT. See [LICENSE](LICENSE).
