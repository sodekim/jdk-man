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
        $backupPath = "$script:ConfigPath.bak"
        Write-Warning "Failed to parse config, backing up to $backupPath and resetting to empty. Error: $_"
        [System.IO.File]::Copy($script:ConfigPath, $backupPath, $true)
        [System.IO.File]::WriteAllText($script:ConfigPath, '{}', [System.Text.UTF8Encoding]::new($false))
        return @{}
    }
}

function Set-JdkConfig([hashtable]$Hash) {
    $json = $Hash | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($script:ConfigPath, $json, [System.Text.UTF8Encoding]::new($false))
}

# ── PATH helpers ──────────────────────────────────────────────────────

# Path equality ignoring trailing backslashes (JAVA_HOME often ends with '\')
function Test-SamePath([string]$PathA, [string]$PathB) {
    return ($PathA -and $PathB -and ($PathA.TrimEnd('\') -eq $PathB.TrimEnd('\')))
}

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
        Manage multiple JDK installations: list available versions, show the active
        JDK, switch for the current session, set a persistent default, add new JDKs,
        and remove old ones.
        Configuration is stored in $env:LOCALAPPDATA\jdk-man\jdk-config.json.

    .PARAMETER Command
        Subcommand to run: list, current, use, default, add, remove.

    .PARAMETER Version
        JDK version key as registered in config (e.g. "8", "17", "21").

    .PARAMETER RemainingArgs
        Extra positional arguments. For "add", this is the JDK root path.

    .EXAMPLE
        jdk list
        List all configured JDK versions with status.

    .EXAMPLE
        jdk current
        Show the active JDK version, its path, and scope (session or persistent).

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

            # Build data and calculate column widths
            $rows = @()
            $maxVer = 6     # Version column width
            $maxPath = 4    # Path column width
            $maxAvail = 7   # Available column width

            foreach ($kv in $config.GetEnumerator()) {
                $ver = $kv.Key
                $path = $kv.Value
                $exists = Test-Path "$path\bin\java.exe"
                $avail = if ($exists) { '[OK]' } else { '[MISSING]' }
                $active = Test-SamePath $env:JAVA_HOME $path

                $verDisplay = if ($active) { "*$ver" } else { $ver }
                $rows += [PSCustomObject]@{
                    Ver = $verDisplay
                    Path = $path
                    Avail = $avail
                }

                if ($verDisplay.Length -gt $maxVer) { $maxVer = $verDisplay.Length }
                if ($path.Length -gt $maxPath) { $maxPath = $path.Length }
                if ($avail.Length -gt $maxAvail) { $maxAvail = $avail.Length }
            }

            # Pad Chinese header to match column width (each CJK char = 2 cells)
            function Pad-Right([string]$s, [int]$width) {
                $cjk = [regex]::Matches($s, '[\u4e00-\u9fff\u3000-\u303f\uff00-\uffef]').Count
                $displayLen = $s.Length + $cjk
                if ($displayLen -lt $width) { $s + (' ' * ($width - $displayLen)) } else { $s }
            }

            $headerVer   = Pad-Right '版本' $maxVer
            $headerPath  = Pad-Right '路径' $maxPath
            $headerAvail = Pad-Right '可用' $maxAvail

            # Header
            Write-Host "$headerVer $headerPath $headerAvail"
            Write-Host ('-' * ($maxVer + 1 + $maxPath + 1 + $maxAvail))

            # Data rows
            foreach ($row in $rows | Sort-Object Ver) {
                $colVer   = $row.Ver.PadRight($maxVer)
                $colPath  = $row.Path.PadRight($maxPath)
                $colAvail = $row.Avail.PadRight($maxAvail)
                Write-Host "$colVer $colPath $colAvail"
            }
        }

        'current' {
            $javaHome = $env:JAVA_HOME
            if (-not $javaHome) {
                Write-Host "No JDK is currently active." -ForegroundColor Yellow
                Write-Host "Use 'jdk use <version>' or 'jdk default <version>' to activate one." -ForegroundColor Gray
                return
            }

            # Find which config version matches
            $matchedVer = $null
            foreach ($kv in $config.GetEnumerator()) {
                if (Test-SamePath $kv.Value $javaHome) {
                    $matchedVer = $kv.Key
                    break
                }
            }

            # Determine scope: check user-level JAVA_HOME
            $userJavaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
            $isPersisted = Test-SamePath $userJavaHome $javaHome
            $scope = if ($isPersisted) { 'Persistent (User)' } else { 'Session only' }

            Write-Host "Version : " -NoNewline
            if ($matchedVer) {
                Write-Host "JDK $matchedVer" -ForegroundColor Green
            } else {
                Write-Host "(unmanaged)" -ForegroundColor Yellow
            }
            Write-Host "Path    : $javaHome" -ForegroundColor Gray
            Write-Host "Scope   : $scope" -ForegroundColor Gray
            Write-Host "Config  : " -NoNewline
            if ($matchedVer) {
                Write-Host $script:ConfigPath
            } else {
                Write-Host "(not registered in jdk-man config)" -ForegroundColor Yellow
            }

            # Show java -version output
            $javaBin = Join-Path $javaHome 'bin\java.exe'
            if (Test-Path $javaBin) {
                Write-Host ''
                & $javaBin -version
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

            if (Test-SamePath $env:JAVA_HOME $config[$Version]) {
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

$script:JdkSubcommands = @('list', 'current', 'use', 'default', 'add', 'remove')
$script:JdkVersionSubcommands = @('use', 'default', 'add', 'remove')

# Side-effect-free version-key reader (completion must never create the config file)
function Get-JdkVersionKeys {
    if (-not (Test-Path $script:ConfigPath)) { return }
    try {
        $content = [System.IO.File]::ReadAllText($script:ConfigPath, [System.Text.UTF8Encoding]::new($false))
        if ([string]::IsNullOrWhiteSpace($content)) { return }
        return ($content | ConvertFrom-Json -AsHashtable).Keys
    }
    catch {
        return
    }
}

function Complete-Subcommand([string]$Prefix) {
    $script:JdkSubcommands |
        Where-Object { $_ -like "$Prefix*" } |
        Sort-Object |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

# Runs in module scope, so it reuses $script:ConfigPath and the helpers above
function Complete-JdkCommand {
    param($wordToComplete, $commandAst, $cursorPosition)

    $elements = @($commandAst.CommandElements)

    # elements[0] is always "jdk"
    if ($elements.Count -eq 1) {
        # "jdk <TAB>" — complete subcommands
        Complete-Subcommand $wordToComplete
        return
    }

    # elements.Count >= 2 — check whether elements[1] is a known subcommand
    $firstArg = $elements[1].Extent.Text

    if ($firstArg -in $script:JdkSubcommands) {
        # Subcommand already fully typed
        if ($firstArg -in $script:JdkVersionSubcommands) {
            # "jdk use <TAB>" or "jdk use 1<TAB>" — complete versions from config
            # When $wordToComplete equals the subcommand itself (no space before TAB),
            # treat the version prefix as empty to show all versions
            $versionPrefix = if ($wordToComplete -eq $firstArg) { '' } else { $wordToComplete }
            Get-JdkVersionKeys |
                Where-Object { $_ -like "$versionPrefix*" } |
                Sort-Object |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
        }
        # Else: "jdk list <TAB>" or "jdk add 17 <TAB>" — let default completion handle it
        return
    }

    # elements[1] is NOT a full subcommand — "jdk u<TAB>", complete subcommands
    Complete-Subcommand $wordToComplete
}

Register-ArgumentCompleter -CommandName jdk -ScriptBlock ${function:Complete-JdkCommand}

Export-ModuleMember -Function jdk
