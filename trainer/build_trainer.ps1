param(
    [Parameter(Mandatory=$true)][string]$Python,
    [Parameter(Mandatory=$true)][string]$BuildDependencies,
    [Parameter(Mandatory=$true)][string]$Compiler,
    [string]$DistDirectory='dist'
)
$ErrorActionPreference='Stop'
$projectPath=$PSScriptRoot
$buildPath=Join-Path $projectPath 'build'
$sourcePath=Join-Path $projectPath 'kronos/codex_solo_trainer.gsc'
$distPath=Join-Path $projectPath $DistDirectory
$compiledPath=Join-Path $projectPath 'kronos/build/codex_solo_trainer_v7'
$decompiledPath=Join-Path $buildPath 'decompiled'
Push-Location $projectPath
try {
    & $Python -m unittest test_channel test_weapon_actions -v
    if($LASTEXITCODE-ne 0){throw 'Protocol tests failed.'}
    & $Compiler gscc $sourcePath -o $compiledPath -g bo7 -p bo7 --name custom_scripts/codex_solo_trainer.gsc
    if($LASTEXITCODE-ne 0){throw 'Script compilation failed.'}
    & $Compiler gscd -g -a -H ($compiledPath+'.gscc') -o $decompiledPath
    if($LASTEXITCODE-ne 0){throw 'Script roundtrip failed.'}
    & $Python verify_script.py (Join-Path $decompiledPath 'hashed/script/script_f95df2bc55cfe53.gsc')
    if($LASTEXITCODE-ne 0){throw 'Static verification failed.'}
    $previousPythonPath=$env:PYTHONPATH
    try {
        $env:PYTHONPATH=$BuildDependencies
        & $Python -m PyInstaller --noconfirm --onedir --windowed --noupx --name BO7_Kronos_Trainer --distpath $distPath --workpath $buildPath --specpath $buildPath --add-data ((Join-Path $projectPath 'resources')+':resources') --add-data ($sourcePath+':kronos') (Join-Path $projectPath 'app.py')
        if($LASTEXITCODE-ne 0){throw 'Executable build failed.'}
    } finally {$env:PYTHONPATH=$previousPythonPath}
    Copy-Item (Join-Path $projectPath 'LEEME.md') (Join-Path $distPath 'BO7_Kronos_Trainer/LEEME.md') -Force
} finally {Pop-Location}
