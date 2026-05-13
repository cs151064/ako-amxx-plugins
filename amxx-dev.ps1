param(
    [ValidateSet('Deploy', 'Build', 'Package', 'Clean', 'List')]
    [string]$Action = 'Deploy',

    [string[]]$Plugin = @(),

    [switch]$Debug,
    [switch]$NoPluginsIni,

    [string]$ServerRoot = 'D:\CounterStrike\hlds'
)

$ErrorActionPreference = 'Stop'

$WorkspaceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModName = 'cstrike'

$ModDir = Join-Path $ServerRoot $ModName
$AmxxDir = Join-Path $ModDir 'addons\amxmodx'
$Compiler = Join-Path $AmxxDir 'scripting\amxxpc.exe'
$ServerIncludeDir = Join-Path $AmxxDir 'scripting\include'
$ServerPluginsDir = Join-Path $AmxxDir 'plugins'
$PluginsIni = Join-Path $AmxxDir 'configs\plugins.ini'

$SrcDir = Join-Path $WorkspaceRoot 'src'
$DistPluginsDir = Join-Path $WorkspaceRoot 'dist\plugins'
$PackageDir = Join-Path $WorkspaceRoot 'packages'
$Manifest = Join-Path $WorkspaceRoot 'config\plugins.local.ini'

$ResourceRoots = @(
    'model'
)

$BlockStart = '; >>> ako managed plugins'
$BlockEnd = '; <<< ako managed plugins'

function Assert-PathExists {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label not found: $Path"
    }
}

function Get-PluginKey {
    param([string]$Name)
    return ([IO.Path]::GetFileNameWithoutExtension($Name)).ToLowerInvariant()
}

function Get-SourceFiles {
    $all = @()
    if (Test-Path -LiteralPath $SrcDir) {
        $all = Get-ChildItem -LiteralPath $SrcDir -Recurse -Filter '*.sma' |
            Where-Object {
                $_.Name -notlike '_*' -and
                $_.FullName -notmatch '\\disabled\\'
            } |
            Sort-Object FullName
    }

    $requestedPlugins = @(
        $Plugin |
            ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne '' }
    )

    if ($requestedPlugins.Count -eq 0) {
        return @($all)
    }

    $byName = @{}
    foreach ($file in $all) {
        $byName[(Get-PluginKey $file.Name)] = $file
    }

    $selected = @()
    foreach ($name in $requestedPlugins) {
        $key = Get-PluginKey $name
        if (-not $byName.ContainsKey($key)) {
            throw "Source plugin not found in src: $name"
        }
        $selected += $byName[$key]
    }

    return @($selected)
}

function Invoke-Build {
    Assert-PathExists $Compiler 'AMXX compiler'
    Assert-PathExists $ServerIncludeDir 'Server include directory'

    New-Item -ItemType Directory -Path $DistPluginsDir -Force | Out-Null

    $sources = @(Get-SourceFiles)
    if ($sources.Count -eq 0) {
        Write-Host 'No .sma files found under src. Nothing to build.'
        return @()
    }

    $built = @()
    foreach ($source in $sources) {
        $outFile = Join-Path $DistPluginsDir ($source.BaseName + '.amxx')
        Write-Host "Compiling $($source.Name) -> $([IO.Path]::GetFileName($outFile))"

        $args = @(
            $source.FullName,
            "-i$ServerIncludeDir",
            "-o$outFile"
        )

        $output = & $Compiler @args 2>&1
        $exitCode = $LASTEXITCODE
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
        }
        if ($exitCode -ne 0 -or -not (Test-Path -LiteralPath $outFile)) {
            throw "Compile failed: $($source.FullName)"
        }

        $built += [PSCustomObject]@{
            Source = $source.FullName
            Plugin = [IO.Path]::GetFileName($outFile)
            Output = $outFile
        }
    }

    return @($built)
}

function Get-ManagedPluginLines {
    param([object[]]$Built)

    if (Test-Path -LiteralPath $Manifest) {
        $manifestLines = @(
            Get-Content -LiteralPath $Manifest |
                ForEach-Object { $_.TrimEnd() } |
                Where-Object { $_.Trim() -ne '' }
        )
        $pluginLines = @($manifestLines | Where-Object { $_.TrimStart() -notmatch '^[;#]' })

        if ($pluginLines.Count -gt 0) {
            return @($manifestLines)
        }
    }

    return @(
        $Built |
            Sort-Object Plugin |
            ForEach-Object {
                if ($Debug) { "$($_.Plugin) debug" } else { $_.Plugin }
            }
    )
}

function Test-ManagedPluginLines {
    param([string[]]$ManagedLines)

    foreach ($line in $ManagedLines) {
        if ($line.TrimStart() -match '^[;#]') {
            continue
        }

        $name = ($line -split '\s+')[0]
        if ($name -notmatch '\.amxx$') {
            $name = "$name.amxx"
        }

        $path = Join-Path $ServerPluginsDir $name
        if (-not (Test-Path -LiteralPath $path)) {
            Write-Warning "plugins.ini will reference a missing plugin: $name"
        }
    }
}

function Set-ManagedPluginsIni {
    param([string[]]$ManagedLines)

    Assert-PathExists $PluginsIni 'plugins.ini'

    $current = @(Get-Content -LiteralPath $PluginsIni)

    $block = @($BlockStart) + $ManagedLines + @($BlockEnd)
    $startIndex = [Array]::IndexOf($current, $BlockStart)
    $endIndex = [Array]::IndexOf($current, $BlockEnd)

    if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {
        $before = if ($startIndex -gt 0) { $current[0..($startIndex - 1)] } else { @() }
        $after = if ($endIndex -lt ($current.Count - 1)) { $current[($endIndex + 1)..($current.Count - 1)] } else { @() }
        $next = @($before) + $block + @($after)
    }
    else {
        $next = @($current) + @('', $BlockStart) + $ManagedLines + @($BlockEnd)
    }

    $oldText = ($current -join "`r`n")
    $newText = ($next -join "`r`n")
    if ($oldText -ne $newText) {
        $backup = "$PluginsIni.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -LiteralPath $PluginsIni -Destination $backup -Force
        Set-Content -LiteralPath $PluginsIni -Value $next -Encoding ASCII
        Write-Host "Updated plugins.ini"
        Write-Host "Backup: $backup"
    }
    else {
        Write-Host 'plugins.ini already up to date'
    }
}

function Invoke-Deploy {
    $built = @(Invoke-Build)
    if ($built.Count -eq 0) {
        return
    }

    Assert-PathExists $ServerPluginsDir 'Server plugins directory'
    foreach ($item in $built) {
        $dest = Join-Path $ServerPluginsDir $item.Plugin
        Copy-Item -LiteralPath $item.Output -Destination $dest -Force
        Write-Host "Deployed $($item.Plugin)"
    }

    foreach ($resourceRoot in $ResourceRoots) {
        $resourcePath = Join-Path $WorkspaceRoot $resourceRoot
        if (Test-Path -LiteralPath $resourcePath) {
            Get-ChildItem -LiteralPath $resourcePath -Force |
                Copy-Item -Destination $ModDir -Recurse -Force
            Write-Host "Deployed resources from $resourceRoot/"
        }
    }

    if (-not $NoPluginsIni) {
        $managed = @(Get-ManagedPluginLines -Built $built)
        Test-ManagedPluginLines -ManagedLines $managed
        Set-ManagedPluginsIni -ManagedLines $managed
    }
}

function Invoke-Package {
    $built = @(Invoke-Build)
    if ($built.Count -eq 0) {
        return
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $root = Join-Path $PackageDir "ako_amxx_$stamp"
    $pkgModDir = Join-Path $root $ModName
    $pkgPlugins = Join-Path $root "$ModName\addons\amxmodx\plugins"

    New-Item -ItemType Directory -Path $pkgModDir -Force | Out-Null
    foreach ($resourceRoot in $ResourceRoots) {
        $resourcePath = Join-Path $WorkspaceRoot $resourceRoot
        if (Test-Path -LiteralPath $resourcePath) {
            Get-ChildItem -LiteralPath $resourcePath -Force |
                Copy-Item -Destination $pkgModDir -Recurse -Force
        }
    }

    New-Item -ItemType Directory -Path $pkgPlugins -Force | Out-Null

    foreach ($item in $built) {
        Copy-Item -LiteralPath $item.Output -Destination (Join-Path $pkgPlugins $item.Plugin) -Force
    }

    $zipPath = "$root.zip"
    Compress-Archive -LiteralPath (Join-Path $root $ModName) -DestinationPath $zipPath -Force
    Write-Host "Package: $zipPath"
}

function Show-List {
    $sources = @(Get-SourceFiles)
    if ($sources.Count -eq 0) {
        Write-Host 'No source plugins found.'
        return
    }

    $sources | ForEach-Object {
        Write-Host "$($_.BaseName)  $($_.FullName)"
    }
}

function Invoke-Clean {
    if (Test-Path -LiteralPath $DistPluginsDir) {
        Get-ChildItem -LiteralPath $DistPluginsDir -Filter '*.amxx' | Remove-Item -Force
        Write-Host "Cleaned $DistPluginsDir"
    }
}

switch ($Action) {
    'Build' { Invoke-Build | Out-Null }
    'Deploy' { Invoke-Deploy }
    'Package' { Invoke-Package }
    'Clean' { Invoke-Clean }
    'List' { Show-List }
}
