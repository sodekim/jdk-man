# Copilot Instructions — jdk-man

Windows JDK version manager. PowerShell 7+ module. No build system, tests, or linter.

## Architecture

- **`jdk-man.psd1`** — Module manifest. Exports a single function `jdk`. Requires PowerShell 7.0+.
- **`jdk-man.psm1`** — All logic lives here. Single entry point `jdk` with subcommands: `list`, `use <ver>`, `default <ver>`, `add <ver> <path>`, `remove <ver>`.
- **Config**: `$env:LOCALAPPDATA\jdk-man\jdk-config.json` — Flat JSON map of `version → JDK root path` (e.g. `{"17":"D:\\sdk\\jdk\\jdk-17"}`). Auto-created as `{}` on first run if missing.

## Key Conventions

- **Config I/O uses .NET methods** (`[System.IO.File]::ReadAllText` / `WriteAllText` with UTF-8 no-BOM) instead of `Get-Content`/`Set-Content` to avoid file locking. Preserve this pattern.
- **Two environment scopes**: `use` modifies only the current session (`$env:JAVA_HOME`, `$env:Path`); `default` persists `JAVA_HOME` at User level via `[Environment]::SetEnvironmentVariable(..., "User")` and ensures `%JAVA_HOME%\bin` is in user PATH (only if absent). `add` only registers the config entry, then interactively prompts (`Read-Host`) whether to set it as default.
- **PATH deduplication**: `Update-SessionPath` strips all known JDK `bin` dirs (from config) and literal `%JAVA_HOME%\bin` / `%JAVA_HOME%/bin` entries before prepending the new bin. Any session PATH manipulation must go through this function.
- **Validation gate**: a JDK path is valid only if `<path>\bin\java.exe` exists. `add`, `use`, and `default` all enforce this.
- **Error handling**: fatal errors (unknown version, invalid path) use `throw`, not `Write-Error` + `return`.
- **User-facing messages** use `Write-Host` with `-ForegroundColor` (Green = success, Yellow = warning/permanent change, Gray = informational).
- **`list` marks the active version** with a `*` prefix when `$env:JAVA_HOME` matches a configured path.
- **`remove` warns** (yellow) when removing the version that is the current `JAVA_HOME`, but does not block the removal.
- **Tab completion** is registered for the `Version` parameter of `jdk` via `Register-ArgumentCompleter`, sourcing keys from the config file.
- **Help** uses comment-based help on the `jdk` function; bare `jdk` (no args) displays `Get-Help jdk`.
