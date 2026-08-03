# Repository Guidelines

## Project Overview

`jdk-man` is a lightweight Windows JDK version manager built on PowerShell 7+. A single command `jdk` registers, switches, and removes multiple JDK installations — no admin rights, no shell overlays.

## Architecture & Data Flow

```
jdk <command> [args]
  │
  ├─→ Get-JdkConfig()          # Reads %LOCALAPPDATA%\jdk-man\jdk-config.json → hashtable
  │
  ├─ list    → Iterate config, check bin\java.exe exists, format table output
  ├─ current → Read $env:JAVA_HOME, match config for version key, compare User registry for scope
  ├─ use     → $env:JAVA_HOME = path → Update-SessionPath → java -version
  ├─ default → [Environment]::SetEnvironmentVariable("JAVA_HOME", path, "User")
  │           → Ensure-UserPathHasJavaBin → Update-SessionPath → java -version
  ├─ add    → config[$ver] = path → Set-JdkConfig → optionally set as default
  └─ remove → config.Remove($ver) → Set-JdkConfig
```

**Two critical paths:**
- **Session scope** (`use`): modifies only the current process environment; lost on terminal close.
- **User scope** (`default`): writes to registry via `[Environment]::SetEnvironmentVariable(..., "User")`; new terminals pick it up automatically. Also ensures `%JAVA_HOME%\bin` is at the front of the user PATH.

**No build system, no dependencies, no test framework** — all logic lives in a single `.psm1` file (~400 lines).

## Key Directories

| Path | Purpose |
|------|---------|
| `jdk-man.psm1` | All logic: config I/O, PATH manipulation, subcommands, tab completion |
| `jdk-man.psd1` | Module manifest: version, exported functions, metadata |
| `release.ps1` | Release helper: bump version, tag, publish to PSGallery |
| `%LOCALAPPDATA%\jdk-man\jdk-config.json` | Runtime config file (generated at runtime, not in repo) |

## Development Commands

No build, test, or lint commands. The development loop is:

```powershell
# Re-import after editing (-Force overwrites loaded module)
Import-Module .\jdk-man.psd1 -Force

# Manual smoke tests
jdk current
jdk list
jdk default 21
jdk add 8 D:\path\to\jdk8
jdk remove 8

# Publish to PSGallery (requires POWERSHELL_GALLERY_API_KEY env var)
./release.ps1 -Version "1.0.1"
```

## Code Conventions

### File I/O: .NET methods only
Use `[System.IO.File]::ReadAllText` / `WriteAllText` with `[System.Text.UTF8Encoding]::new($false)` (UTF-8 no-BOM). **Never** use `Get-Content` / `Set-Content` — they cause file locking issues.

### Error handling: throw
Fatal errors (unknown version, invalid path) use `throw`. Do **not** use `Write-Error` + `return`.

### User messages: Write-Host with color semantics
| Color | Meaning |
|-------|---------|
| `Green` | Success operation |
| `Yellow` | Warning / persistent change notification |
| `Gray` | Informational message (e.g., config already exists) |

### current command scope detection
`current` reads `$env:JAVA_HOME` and looks up the matching version in config. Scope logic:
- Compare `[Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')` with session `$env:JAVA_HOME`
- Paths match → `Persistent (User)`, otherwise → `Session only`
- No match in config → marked as `(unmanaged)`, still shows path and scope

### PATH deduplication
`Update-SessionPath` must be the single function that modifies the session PATH. It:
1. Collects all known JDK `bin` directories from config, normalized to full paths
2. Removes every PATH entry whose full path matches a known JDK `bin` (including the new one), plus entries matching `%JAVA_HOME%\bin` or `%JAVA_HOME%/bin`
3. Prepends the new bin directory exactly once

**Every session PATH mutation must go through this function.**

### Validation gate
The sole criterion for a valid JDK path: `<path>\bin\java.exe` must exist. Enforced by `add`, `use`, and `default` commands.

### list command CJK alignment
`list` includes an internal `Pad-Right` helper that manually computes CJK character display width (Unicode ranges `\u4e00-\u9fff` etc., each char = 2 cells) for proper Chinese header alignment.

### Tab completion
Two classes (`JdkSubcommandCompleter`, `JdkVersionCompleter`) implement `IArgumentCompleter` and are bound via `[ArgumentCompleter()]` attributes on the `jdk` function's `Command` and `Version` parameters. The subcommand completer returns static command names; the version completer reads version keys from config JSON. Class-based completers are strongly typed (no stray output leaks into PSReadLine rendering) and attribute-bound (no duplicate registration on `Import-Module -Force`).

### Comment-based help
The `jdk` function uses PowerShell comment-based help. Running `jdk` with no arguments is equivalent to `Get-Help jdk`.

## Runtime Constraints

- **Runtime**: PowerShell 7.0+ (`pwsh.exe`), not Windows PowerShell 5.x
- **Platform**: Windows 10 / 11 only
- **No package manager, no build tool**
- **Publish channel**: PowerShell Gallery (`Publish-PSResource`)
