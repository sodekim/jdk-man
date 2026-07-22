param(
    [Parameter(Mandatory)]
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'
$tmp = Join-Path $env:TEMP 'jdk-man'

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item $tmp -ItemType Directory -Force | Out-Null
Copy-Item "$PSScriptRoot\jdk-man.psd1", "$PSScriptRoot\jdk-man.psm1" $tmp

try {
    Publish-PSResource -Path $tmp -ApiKey $ApiKey -Repository PSGallery
    Write-Host "Published successfully." -ForegroundColor Green
}
finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
