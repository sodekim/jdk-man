param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Version
)

$ErrorActionPreference = 'Stop'

# git is a native command: $ErrorActionPreference alone will not stop on a
# non-zero exit code. Wrap every call so a failed step aborts the release.
function Invoke-ReleaseGit {
    param([string[]]$Arguments)
    git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

$ApiKey = $env:POWERSHELL_GALLERY_API_KEY
if (-not $ApiKey) { throw "Environment variable POWERSHELL_GALLERY_API_KEY is not set." }

# Update module version in manifest
$manifestPath = Join-Path $PSScriptRoot 'jdk-man.psd1'
$manifest = Get-Content $manifestPath -Raw
$manifest = $manifest -replace "(?<=ModuleVersion\s*=\s*')[^']*", $Version
Set-Content $manifestPath $manifest -NoNewline
Write-Host "Module version updated to $Version." -ForegroundColor Green

# Commit version bump and create git tag
$tag = "v$Version"
Invoke-ReleaseGit @('add', $manifestPath)
Invoke-ReleaseGit @('commit', '-m', "chore(release): v$Version")
Invoke-ReleaseGit @('tag', $tag)
Write-Host "Committed and tagged $tag." -ForegroundColor Green

# Publish to PSGallery
$tmp = Join-Path $env:TEMP 'jdk-man'
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item $tmp -ItemType Directory -Force | Out-Null
Copy-Item "$PSScriptRoot\jdk-man.psd1", "$PSScriptRoot\jdk-man.psm1" $tmp

try {
    Publish-PSResource -Path $tmp -ApiKey $ApiKey -Repository PSGallery
    Write-Host "Published successfully." -ForegroundColor Green

    # Push tag to remote
    Invoke-ReleaseGit @('push', 'origin', $tag)
    Write-Host "Tag $tag pushed to remote." -ForegroundColor Green
}
finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
