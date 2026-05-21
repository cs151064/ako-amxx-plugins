param(
    [ValidateSet('Configure', 'Build', 'Deploy', 'Package', 'Clean', 'List')]
    [string]$Action = 'Build',

    [switch]$Core,
    [switch]$NoMonsters,

    [string]$Configuration = 'Release',
    [string]$ServerRoot = 'D:\CounterStrike\hlds'
)

$ErrorActionPreference = 'Stop'

$WorkspaceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceDir = Join-Path $WorkspaceRoot 'src\arpg'
$BuildDir = Join-Path $WorkspaceRoot 'build\arpg'
$DistDir = Join-Path $WorkspaceRoot 'dist'
$ModDir = Join-Path $ServerRoot 'cstrike'
$AkoAddonDir = Join-Path $ModDir 'addons\ako-rpg'
$MetamodPluginsIni = Join-Path $ModDir 'addons\metamod\plugins.ini'

function Find-VcVars32 {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) {
        return $null
    }

    $installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $installPath) {
        return $null
    }

    $vcvars = Join-Path $installPath 'VC\Auxiliary\Build\vcvars32.bat'
    if (Test-Path -LiteralPath $vcvars) {
        return $vcvars
    }

    return $null
}

function Invoke-InVcEnv {
    param([string]$Command)

    $cmake = Get-Command cmake.exe -ErrorAction SilentlyContinue
    $cl = Get-Command cl.exe -ErrorAction SilentlyContinue
    if ($cmake -and $cl) {
        powershell -NoProfile -ExecutionPolicy Bypass -Command $Command
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed: $Command"
        }
        return
    }

    $vcvars = Find-VcVars32
    if (-not $vcvars) {
        throw 'Could not find x86 MSVC build environment. Install Visual Studio Build Tools with C++ x86/x64 tools, or run this task from a Developer PowerShell.'
    }

    $cmd = "`"$vcvars`" && powershell -NoProfile -ExecutionPolicy Bypass -Command `"$Command`""
    cmd.exe /d /c $cmd
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $Command"
    }
}

function Invoke-Configure {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

    $buildCore = if ($Core) { 'ON' } else { 'OFF' }
    $buildMonsters = if ($NoMonsters) { 'OFF' } else { 'ON' }
    $command = "cmake -S `"$SourceDir`" -B `"$BuildDir`" -G Ninja -DCMAKE_BUILD_TYPE=$Configuration -DARPG_BUILD_CORE=$buildCore -DARPG_BUILD_MONSTERS=$buildMonsters"
    Invoke-InVcEnv $command
}

function Invoke-Build {
    if (-not (Test-Path -LiteralPath (Join-Path $BuildDir 'build.ninja'))) {
        Invoke-Configure
    }

    Invoke-InVcEnv "cmake --build `"$BuildDir`" --config $Configuration"
}

function Copy-ArpgResources {
    param([string]$DestinationModDir)

    $resourcePairs = @(
        @{ Source = Join-Path $WorkspaceRoot 'model\models\ako-rpg'; Destination = Join-Path $DestinationModDir 'models\ako-rpg' },
        @{ Source = Join-Path $WorkspaceRoot 'model\sound\ako-rpg'; Destination = Join-Path $DestinationModDir 'sound\ako-rpg' },
        @{ Source = Join-Path $WorkspaceRoot 'model\sprites\ako-rpg'; Destination = Join-Path $DestinationModDir 'sprites\ako-rpg' }
    )

    foreach ($pair in $resourcePairs) {
        if (Test-Path -LiteralPath $pair.Source) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $pair.Destination) -Force | Out-Null
            Copy-Item -LiteralPath $pair.Source -Destination (Split-Path -Parent $pair.Destination) -Recurse -Force
        }
    }
}

function Set-MetamodPluginLine {
    param([string]$Line)

    if (-not (Test-Path -LiteralPath $MetamodPluginsIni)) {
        Write-Warning "Metamod plugins.ini not found: $MetamodPluginsIni"
        return
    }

    $lines = @(Get-Content -LiteralPath $MetamodPluginsIni)
    if ($lines -contains $Line) {
        return
    }

    $backup = "$MetamodPluginsIni.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item -LiteralPath $MetamodPluginsIni -Destination $backup -Force
    $lines + $Line | Set-Content -LiteralPath $MetamodPluginsIni -Encoding ASCII
    Write-Host "Updated Metamod plugins.ini"
    Write-Host "Backup: $backup"
}

function Invoke-Deploy {
    Invoke-Build

    New-Item -ItemType Directory -Path $AkoAddonDir -Force | Out-Null

    $dlls = @('arpg_core.dll', 'arpg_monsters.dll')
    foreach ($dll in $dlls) {
        $source = Join-Path $DistDir $dll
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $AkoAddonDir $dll) -Force
            Write-Host "Deployed $dll"
        }
    }

    $monsterCfg = Join-Path $SourceDir 'arpg_monsters\cfg'
    if (Test-Path -LiteralPath $monsterCfg) {
        Copy-Item -Path (Join-Path $monsterCfg '*') -Destination $AkoAddonDir -Force
        Write-Host 'Deployed ARPG monster cfg'
    }

    Copy-ArpgResources -DestinationModDir $ModDir
    Write-Host 'Deployed ARPG resources'

    if (Test-Path -LiteralPath (Join-Path $DistDir 'arpg_core.dll')) {
        Set-MetamodPluginLine 'win32 addons/ako-rpg/arpg_core.dll'
    }
    if (Test-Path -LiteralPath (Join-Path $DistDir 'arpg_monsters.dll')) {
        Set-MetamodPluginLine 'win32 addons/ako-rpg/arpg_monsters.dll'
    }
}

function Invoke-Package {
    Invoke-Build

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $root = Join-Path (Join-Path $WorkspaceRoot 'packages') "ako_arpg_$stamp"
    $pkgMod = Join-Path $root 'cstrike'
    $pkgAddon = Join-Path $pkgMod 'addons\ako-rpg'

    New-Item -ItemType Directory -Path $pkgAddon -Force | Out-Null
    foreach ($dll in @('arpg_core.dll', 'arpg_monsters.dll')) {
        $source = Join-Path $DistDir $dll
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $pkgAddon $dll) -Force
        }
    }

    Copy-Item -Path (Join-Path $SourceDir 'arpg_monsters\cfg\*') -Destination $pkgAddon -Force
    Copy-ArpgResources -DestinationModDir $pkgMod

    $zip = "$root.zip"
    Compress-Archive -LiteralPath $pkgMod -DestinationPath $zip -Force
    Write-Host "Package: $zip"
}

function Invoke-Clean {
    if (Test-Path -LiteralPath $BuildDir) {
        Remove-Item -LiteralPath $BuildDir -Recurse -Force
    }
    foreach ($dll in @('arpg_core.dll', 'arpg_monsters.dll')) {
        $path = Join-Path $DistDir $dll
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

function Show-List {
    Write-Host "Source: $SourceDir"
    Write-Host "Build:  $BuildDir"
    Write-Host "Dist:   $DistDir"
    Write-Host 'Targets:'
    Write-Host '  arpg_monsters (default)'
    Write-Host '  arpg_core     (-Core, requires AMXX module SDK + SQLite)'
}

switch ($Action) {
    'Configure' { Invoke-Configure }
    'Build' { Invoke-Build }
    'Deploy' { Invoke-Deploy }
    'Package' { Invoke-Package }
    'Clean' { Invoke-Clean }
    'List' { Show-List }
}
