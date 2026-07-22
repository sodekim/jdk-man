# jdk-man.psm1 — Windows JDK version manager (PowerShell 7+ module)

$script:ConfigDir  = Join-Path $env:LOCALAPPDATA 'jdk-man'
$script:ConfigPath = Join-Path $script:ConfigDir 'jdk-config.json'

# ── Config I/O (.NET methods, UTF-8 no-BOM) ──────────────────────────

function Get-JdkConfig {
    if (-not (Test-Path $script:ConfigPath)) {
        $null = New-Item -Path $script:ConfigDir -ItemType Directory -Force
        [System.IO.File]::WriteAllText($script:ConfigPath, '{}', [System.Text.UTF8Encoding]::new($false))
        Write-Host "Created config: $script:ConfigPath" -ForegroundColor Gray
        return @{}
    }
    try {
        $content = [System.IO.File]::ReadAllText($script:ConfigPath, [System.Text.UTF8Encoding]::new($false))
        if ([string]::IsNullOrWhiteSpace($content)) { return @{} }
        $hash = $content | ConvertFrom-Json -AsHashtable
        foreach ($k in @($hash.Keys)) {
            if ($hash[$k] -isnot [string]) {
                Write-Warning "Invalid entry for version '$k' in config, removing."
                $hash.Remove($k)
            }
        }
        return $hash
    }
    catch {
        Write-Warning "Failed to parse config, resetting to empty. Error: $_"
        [System.IO.File]::WriteAllText($script:ConfigPath, '{}', [System.Text.UTF8Encoding]::new($false))
        return @{}
    }
}

function Set-JdkConfig([hashtable]$Hash) {
    $json = $Hash | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($script:ConfigPath, $json, [System.Text.UTF8Encoding]::new($false))
}

# ── PATH helpers ──────────────────────────────────────────────────────

function Update-SessionPath([string]$NewBin, [hashtable]$Config) {
    $knownBins = foreach ($p in $Config.Values) {
        $bin = Join-Path $p 'bin'
        if ($bin -ne $NewBin) { $bin }
    }

    $variablePatterns = @('%JAVA_HOME%\bin', '%JAVA_HOME%/bin')

    $filtered = ($env:Path -split ';') | Where-Object {
        $item = $_
        if (-not $item) { return $false }
        if ($item -in $knownBins) { return $false }
        foreach ($pat in $variablePatterns) {
            if ($item -like $pat) { return $false }
        }
        $true
    }

    $env:Path = "$NewBin;$($filtered -join ';')"
}

function Ensure-UserPathHasJavaBin {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $target   = '%JAVA_HOME%\bin'
    $entries  = if ($userPath) { $userPath -split ';' } else { @() }

    if ($entries -contains $target) {
        Write-Host "[User] %JAVA_HOME%\bin already in user PATH" -ForegroundColor Gray
        return
    }

    $newPath = if ([string]::IsNullOrEmpty($userPath)) {
        $target
    } else {
        "$target;$($userPath.Trim(';'))"
    }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host "[User] Added %JAVA_HOME%\bin to beginning of user PATH" -ForegroundColor Green
}

# ── Main entry point ─────────────────────────────────────────────────

function jdk {
    <#
    .SYNOPSIS
        Windows JDK version manager.

    .DESCRIPTION
        Manage multiple JDK installations: list available versions, switch for the
        current session, set a persistent default, add new JDKs, and remove old ones.
        Configuration is stored in $env:LOCALAPPDATA\jdk-man\jdk-config.json.

    .PARAMETER Command
        Subcommand to run: list, use, default, add, remove.

    .PARAMETER Version
        JDK version key as registered in config (e.g. "8", "17", "21").

    .PARAMETER RemainingArgs
        Extra positional arguments. For "add", this is the JDK root path.

    .EXAMPLE
        jdk list
        List all configured JDK versions with status.

    .EXAMPLE
        jdk use 17
        Switch JAVA_HOME and PATH for the current session only.

    .EXAMPLE
        jdk default 21
        Permanently set user-level JAVA_HOME and ensure %JAVA_HOME%\bin is in user PATH.

    .EXAMPLE
        jdk add 17 D:\sdk\jdk\jdk-17.0.18+8
        Register a JDK installation and optionally set it as default.

    .EXAMPLE
        jdk remove 8
        Remove a JDK version from config.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Command,

        [Parameter(Position = 1)]
        [string]$Version,

        [Parameter(ValueFromRemainingArguments)]
        [string[]]$RemainingArgs
    )

    if (-not $Command) {
        Get-Help jdk
        return
    }

    $config = Get-JdkConfig

    switch ($Command.ToLower()) {

        'list' {
            if ($config.Count -eq 0) {
                Write-Host "No JDK versions configured. Use 'jdk add <version> <path>' to add one." -ForegroundColor Yellow
                return
            }
            Write-Host "Available JDK versions (from $script:ConfigPath):"
            foreach ($kv in $config.GetEnumerator() | Sort-Object Key) {
                $path   = $kv.Value
                $exists = Test-Path "$path\bin\java.exe"
                $status = if ($exists) { '[OK]' } else { '[MISSING]' }
                $mark   = if ($env:JAVA_HOME -eq $path) { '*' } else { ' ' }
                Write-Host "$mark $($kv.Key) - $path $status"
            }
        }

        'use' {
            if (-not $Version) { throw "Usage: jdk use <version>" }
            $path = $config[$Version]
            if (-not $path) { throw "Unknown version '$Version'. Available: $($config.Keys -join ', ')" }
            if (-not (Test-Path "$path\bin\java.exe")) { throw "JDK $Version not found at '$path'" }

            $env:JAVA_HOME = $path
            Update-SessionPath "$path\bin" $config
            Write-Host "[Session] Switched to JDK $Version : $path" -ForegroundColor Green
            Write-Host ''
            java -version
        }

        'default' {
            if (-not $Version) { throw "Usage: jdk default <version>" }
            $path = $config[$Version]
            if (-not $path) { throw "Unknown version '$Version'. Available: $($config.Keys -join ', ')" }
            if (-not (Test-Path "$path\bin\java.exe")) { throw "JDK $Version not found at '$path'" }

            [Environment]::SetEnvironmentVariable('JAVA_HOME', $path, 'User')
            Ensure-UserPathHasJavaBin
            $env:JAVA_HOME = $path
            Update-SessionPath "$path\bin" $config
            Write-Host "[User] JAVA_HOME permanently set to JDK $Version : $path" -ForegroundColor Yellow
            java -version
        }

        'add' {
            $pathArg = $RemainingArgs[0]
            if (-not $Version -or -not $pathArg) { throw "Usage: jdk add <version> <path>" }
            $pathArg = $pathArg.TrimEnd('\')
            if (-not (Test-Path "$pathArg\bin\java.exe")) { throw "Invalid path: '$pathArg' does not contain bin\java.exe" }

            if ($config.ContainsKey($Version)) {
                Write-Warning "Version '$Version' already exists with path '$($config[$Version])'. Overwriting."
            }
            $config[$Version] = $pathArg
            Set-JdkConfig $config
            Write-Host "[Config] Added/updated version $Version -> $pathArg" -ForegroundColor Green

            $answer = Read-Host "Set JDK $Version as default? (y/N)"
            if ($answer -match '^[yY]') {
                [Environment]::SetEnvironmentVariable('JAVA_HOME', $pathArg, 'User')
                Ensure-UserPathHasJavaBin
                $env:JAVA_HOME = $pathArg
                Update-SessionPath "$pathArg\bin" $config
                Write-Host "[User] JAVA_HOME permanently set to JDK $Version : $pathArg" -ForegroundColor Yellow
                java -version
            }
        }

        'remove' {
            if (-not $Version) { throw "Usage: jdk remove <version>" }
            if (-not $config.ContainsKey($Version)) { throw "Unknown version '$Version'. Available: $($config.Keys -join ', ')" }

            if ($env:JAVA_HOME -eq $config[$Version]) {
                Write-Warning "Version '$Version' is the current JAVA_HOME. It will be removed from config but JAVA_HOME will not be changed."
            }

            $config.Remove($Version)
            Set-JdkConfig $config
            Write-Host "[Config] Removed version $Version" -ForegroundColor Green
        }

        default {
            Write-Warning "Unknown command '$Command'."
            Get-Help jdk
        }
    }
}

# ── Tab completion ────────────────────────────────────────────────────

Register-ArgumentCompleter -CommandName jdk -ParameterName Version -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $cfgPath = Join-Path $env:LOCALAPPDATA 'jdk-man\jdk-config.json'
    if (-not (Test-Path $cfgPath)) { return }
    $content = [System.IO.File]::ReadAllText($cfgPath, [System.Text.UTF8Encoding]::new($false))
    if ([string]::IsNullOrWhiteSpace($content)) { return }
    ($content | ConvertFrom-Json -AsHashtable).Keys |
        Where-Object { $_ -like "$wordToComplete*" } |
        Sort-Object |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

Export-ModuleMember -Function jdk
