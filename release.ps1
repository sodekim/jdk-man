param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Version,

    [Parameter(Mandatory)]
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'

# Update module version in manifest (.NET I/O, UTF-8 no BOM — never Get-Content/Set-Content)
$manifestPath = Join-Path $PSScriptRoot 'jdk-man.psd1'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$manifest = [System.IO.File]::ReadAllText($manifestPath, $utf8NoBom)
$manifest = $manifest -replace "(?<=ModuleVersion\s*=\s*')[^']*'", "'$Version'"
[System.IO.File]::WriteAllText($manifestPath, $manifest, $utf8NoBom)
Write-Host "Module version updated to $Version." -ForegroundColor Yellow

# Commit the version bump so the tag points at the released content
git add -- jdk-man.psd1
git commit -m "chore(release): bump module version to $Version"
Write-Host "Committed version bump." -ForegroundColor Yellow

# Create git tag locally
$tag = "v$Version"
git tag $tag
Write-Host "Created tag $tag." -ForegroundColor Yellow

# Publish to PSGallery
if (-not (Get-Command Publish-PSResource -ErrorAction SilentlyContinue)) {
    throw "Publish-PSResource not found. Install the Microsoft.PowerShell.PSResourceGet module (bundled with PowerShell 7.4+)."
}
$tmp = Join-Path $env:TEMP 'jdk-man'
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item $tmp -ItemType Directory -Force | Out-Null
Copy-Item "$PSScriptRoot\jdk-man.psd1", "$PSScriptRoot\jdk-man.psm1" $tmp

try {
    Publish-PSResource -Path $tmp -ApiKey $ApiKey -Repository PSGallery
    Write-Host "Published successfully." -ForegroundColor Green

    # Push tag to remote
    git push origin $tag
    Write-Host "Tag $tag pushed to remote." -ForegroundColor Green
}
finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
