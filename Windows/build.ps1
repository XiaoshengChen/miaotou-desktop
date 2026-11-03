$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'Miaotou.csproj'
$output = Join-Path $PSScriptRoot '../dist/windows-x64'
dotnet publish $project -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o $output
if ($LASTEXITCODE -ne 0) { throw 'Windows publish failed' }
Write-Output (Join-Path $output 'Miaotou.exe')
