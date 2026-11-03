<#
.SYNOPSIS
    Installs La Ruta del 60 into WoW Forever (Windows).
.EXAMPLE
    .\scripts\deploy.ps1
    .\scripts\deploy.ps1 -WowPath "D:\Games\World of Warcraft\_forever_"
    .\scripts\deploy.ps1 -Source release -Repo user/larutadel60
#>
[CmdletBinding()]
param(
    [string]$WowPath = $env:WOW_FOREVER_PATH,
    [ValidateSet("git", "release")]
    [string]$Source = "git",
    [string]$Repo = "",
    [string]$RepoPath = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocol]::Tls12
$ProgressPreference = "SilentlyContinue"
$AddonName = "LaRutaDel60"

if (-not $WowPath) {
    $roots = @("C:\Program Files (x86)\World of Warcraft", "C:\Program Files\World of Warcraft", "D:\World of Warcraft")
    $flavors = @("_forever_", "_camelot_", "_classic_")
    $WowPath = @(foreach ($flavor in $flavors) {
        foreach ($root in $roots) {
            $candidate = Join-Path $root $flavor
            if (Test-Path -LiteralPath $candidate) { $candidate }
        }
    }) | Select-Object -First 1
}
if (-not $WowPath -or -not (Test-Path -LiteralPath $WowPath)) {
    throw "WoW Forever folder not found. Pass -WowPath 'C:\...\World of Warcraft\_forever_' or set WOW_FOREVER_PATH."
}
Write-Host "WoW folder: $WowPath"

$AddOns = Join-Path $WowPath "Interface\AddOns"
New-Item -ItemType Directory -Force -Path $AddOns | Out-Null
$Target = Join-Path $AddOns $AddonName

if ($Source -eq "git") {
    git -C $RepoPath pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw "git pull failed in $RepoPath" }
    $From = Join-Path $RepoPath "addon\$AddonName"
}
else {
    if (-not $Repo) { throw "-Source release requires -Repo owner/repository" }
    $release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like "$AddonName-*.zip" } | Select-Object -First 1
    if (-not $asset) { throw "Release $($release.tag_name) has no addon zip" }
    $tmp = Join-Path $env:TEMP "$AddonName-deploy"
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $zip = Join-Path $tmp "addon.zip"
    Invoke-WebRequest -UseBasicParsing $asset.browser_download_url -OutFile $zip
    Expand-Archive $zip -DestinationPath $tmp
    $From = Join-Path $tmp $AddonName
    Write-Host "Release: $($release.tag_name)"
}

if (-not (Test-Path -LiteralPath (Join-Path $From "$AddonName.toc"))) { throw "$AddonName.toc not found in $From" }
if (Test-Path -LiteralPath $Target) {
    if ((Get-Item -LiteralPath $Target -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Write-Host "Note: $Target is a junction/symlink; removing only the link."
        (Get-Item -LiteralPath $Target -Force).Delete()
    }
    else {
        Remove-Item -LiteralPath $Target -Recurse -Force
    }
}
Copy-Item -LiteralPath $From -Destination $Target -Recurse
Write-Host "Installed into $Target" -ForegroundColor Green
Write-Host "In game: /reload  (then /ruta to see the version)"
