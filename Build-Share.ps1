param([string]$Repository='kalyman1997/omnipotent',[string]$Tag='offline-1.0',[string]$OutputPath="$PSScriptRoot\..\Omnipotent-Compartir",[string]$ObjectStore="$PSScriptRoot\data\objects")
$ErrorActionPreference='Stop'
if($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -or $Tag -notmatch '^[A-Za-z0-9_.-]+$'){throw 'Repositorio o tag no valido.'}
$out=[IO.Path]::GetFullPath($OutputPath)
if(Test-Path -LiteralPath $out){throw 'El destino ya existe. Elige otra carpeta para conservar la entrega anterior.'}
[IO.Directory]::CreateDirectory($out)|Out-Null
$assets=Join-Path $out 'release-assets';$source=Join-Path $out 'repository'
[IO.Directory]::CreateDirectory($assets)|Out-Null
[IO.Directory]::CreateDirectory($source)|Out-Null
$runtime=@('Hybrid.ps1','OfflinePackage.ps1','Branding.ps1','Portable.ps1','package.manifest.txt','compatibility.json','distribution.json','assets/umbral_ready_guard_post.lua')
$code=@('Launcher.cs','Interface.cs','Bundle.cs','launcher.manifest','build.ps1','Build-Share.ps1','Publish-GitHub.ps1','LEEME.txt','README.md','RELEASE-NOTES.txt')
foreach($name in @($runtime)+@($code)){
    $from=Join-Path $PSScriptRoot $name;$to=Join-Path $source $name
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to))|Out-Null
    [IO.File]::Copy($from,$to,$false)
}
[ordered]@{schema=1;downloadBaseUrl="https://github.com/$Repository/releases/download/$Tag/";release=$Tag;repository=$Repository}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $source 'distribution.json') -Encoding UTF8
[IO.File]::Copy((Join-Path $PSScriptRoot 'RELEASE-NOTES.txt'),(Join-Path $out 'RELEASE-NOTES.txt'),$false)
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$args=@('/nologo','/target:winexe','/platform:x64','/optimize+','/utf8output','/reference:System.Core.dll','/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.Xml.dll','/reference:System.Web.Extensions.dll','/reference:Microsoft.CSharp.dll',"/win32manifest:$source\launcher.manifest","/out:$assets\Omnipotent.exe","$source\Launcher.cs","$source\Interface.cs","$source\Bundle.cs")
foreach($name in $runtime){$args+=('/resource:'+(Join-Path $source $name)+',Omnipotent.Bundle.'+$name)}
& $compiler @args
if($LASTEXITCODE-ne 0){throw 'No se pudo compilar el launcher compartible.'}
$manifest=Join-Path $source 'package.manifest.txt'
if((Get-FileHash -LiteralPath $manifest).Hash.ToLowerInvariant()-ne '55926f6089b8a8362755e84a9094dd95358726237b9a10e893e0c98def58d8e0'){throw 'Manifiesto alterado.'}
$seen=@{};$total=0L;$count=0
foreach($line in Get-Content -LiteralPath $manifest){
    if($line-notmatch '^f\s'){continue};$v=$line-split "`t";$hash=$v[2];$size=[long]$v[3]
    if($hash-notmatch '^[a-f0-9]{64}$'){throw 'Hash invalido.'}
    $count++;if($seen.ContainsKey($hash)){continue}
    $path=Join-Path $ObjectStore $hash
    if(!(Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length-ne $size -or (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()-ne $hash){throw ('Objeto ausente o corrupto: '+$hash)}
    [IO.File]::Copy($path,(Join-Path $assets $hash),$false);$total+=$size;$seen[$hash]=$true
}
if($count-ne 439){throw 'El paquete debe contener 439 registros.'}
$inventory=@(Get-ChildItem -LiteralPath $assets -File|ForEach-Object{[pscustomobject]@{name=$_.Name;size=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})
[ordered]@{repository=$Repository;tag=$Tag;createdUtc=[DateTime]::UtcNow.ToString('o');records=$count;uniquePayloads=$seen.Count;payloadBytes=$total;assets=$inventory}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $out 'release-inventory.json') -Encoding UTF8
[IO.File]::WriteAllText((Join-Path $source '.gitignore'),"data/`nsettings.xml`nultima-operacion.txt`n*.exe`n*.png`nrelease-assets/`n",[Text.UTF8Encoding]::new($false))
[pscustomobject]@{Folder=$out;LauncherBytes=(Get-Item "$assets\Omnipotent.exe").Length;UniquePayloads=$seen.Count;PayloadBytes=$total}|ConvertTo-Json
