$ModuleManifestName = "posh-semver.psd1"
$TestModuleManifestPath = Join-Path $PSScriptRoot $ModuleManifestName

Import-Module $TestModuleManifestPath -Force -ErrorAction Stop

if (-not (Test-Path $TestDrive)) { New-Item $TestDrive -ItemType Directory -Force }