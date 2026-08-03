# jdk-man

[English](./README.md) | [简体中文](./README.zh-CN.md)

A lightweight Windows JDK version manager for PowerShell 7+. Register, switch,
and remove multiple Java Development Kit installations from a single command — no
admin prompts, no shell overlays, no fuss.

```powershell
jdk use 17
java -version
```

---

## Features

- **One command, many JDKs** — `list`, `current`, `use`, `default`, `add`, `remove`
- **Two scopes** — `use` switches the current session only; `default` persists
  `JAVA_HOME` and `PATH` at the Windows User level
- **Tab completion** — subcommands and version keys are completed from your config
- **Validation gate** — only paths with a real `bin\java.exe` are accepted
- **PATH-safe** — stale JDK `bin` entries are stripped before the new one is
  prepended, so no duplicates pile up
- **Zero dependencies** — pure PowerShell, no native binaries, no build step

## Requirements

- Windows 10 / 11
- PowerShell 7.0 or later (`pwsh`)
- At least one JDK installed somewhere on disk

## Installation

### From the PowerShell Gallery

```powershell
Install-Module -Name jdk-man -Repository PSGallery
```

### From source

Clone the repo and import the module directly:

```powershell
git clone https://github.com/sodekim/jdk-man.git
Import-Module .\jdk-man\jdk-man.psd1
```

To make it permanent, copy `jdk-man.psd1` and `jdk-man.psm1` into one of your
`$env:PSModulePath` directories (e.g. `~\Documents\PowerShell\Modules\jdk-man`).

## Quick start

```powershell
# Register a JDK you already have on disk
jdk add 17 D:\sdk\jdk\jdk-17.0.18+8

# Show the active JDK version and scope
jdk current

# List configured versions (active one is marked with *)
jdk list

# Switch for the current session only
jdk use 17

# Set a persistent default across new shells
jdk default 21

# Remove a version from config
jdk remove 8
```

## Commands

| Command             | Scope            | Description                                                          |
| ------------------- | ---------------- | -------------------------------------------------------------------- |
| `jdk list`          | read-only        | Print all configured versions with availability status.             |
| `jdk current`      | read-only        | Show active JDK version, path, and scope (session or persistent), its config registration, and `java -version` output. |
| `jdk use <ver>`     | current session  | Set `JAVA_HOME` and prepend `<jdk>\bin` to the session `PATH`.       |
| `jdk default <ver>` | User (persisted) | Set `JAVA_HOME` at the User level and ensure `%JAVA_HOME%\bin` is in user `PATH`. Also applies to the current session. |
| `jdk add <ver> <path>` | config         | Register a JDK root (must contain `bin\java.exe`), then prompt to set it as default. Overwrites an existing version after a warning. |
| `jdk remove <ver>`  | config           | Remove a version from config. Warns if it is the active `JAVA_HOME`. |

> [!NOTE]
> `use` changes only the running shell. Close the terminal and the change is
> gone. `default` writes to the User environment — new terminals pick it up
> automatically.

## Configuration

All state lives in a single JSON file:

```
%LOCALAPPDATA%\jdk-man\jdk-config.json
```

It is a flat map of `version → JDK root path` and is auto-created as `{}` on
first run.

```json
{
  "8":  "D:\\sdk\\jdk\\jdk-1.8.0_421",
  "17": "D:\\sdk\\jdk\\jdk-17.0.18+8",
  "21": "D:\\sdk\\jdk\\jdk-21.0.5+11"
}
```

You can edit this file by hand — `jdk-man` reads it on every invocation, drops
entries that fail to parse, and backs up a corrupt file to `jdk-config.json.bak`
before resetting it.

## Publishing

A `release.ps1` helper is included for maintainers:

```powershell
./release.ps1 -Version "1.0.1" -ApiKey <PSGallery-API-key>
```

It bumps the module version in the manifest, commits the bump, creates a git
tag, stages the manifest and module into a temp directory, calls
`Publish-PSResource` against PSGallery, and pushes the git tag to remote.
`Publish-PSResource` ships with PowerShell 7.4+ (via the
`Microsoft.PowerShell.PSResourceGet` module); on older 7.x install that module
first.

## License

[MIT](./LICENSE) — © sodekim.