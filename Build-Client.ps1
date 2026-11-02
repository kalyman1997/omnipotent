param([Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference='Stop'
$output=[IO.Path]::GetFullPath($OutputPath)
if(Test-Path -LiteralPath $output){throw 'El destino ya existe; conserva la version anterior.'}
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output))|Out-Null
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$compileArgs=@('/nologo','/target:winexe','/platform:x64','/optimize+','/utf8output','/reference:System.Core.dll','/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.Xml.dll','/reference:System.Web.Extensions.dll','/reference:Microsoft.CSharp.dll',"/win32manifest:$PSScriptRoot\launcher.manifest","/out:$output")
foreach($name in @('Launcher.cs','Interface.cs','Bundle.cs','GameDiscovery.cs')){$compileArgs+=(Join-Path $PSScriptRoot $name)}
foreach($name in @('Hybrid.ps1','OfflinePackage.ps1','Branding.ps1','Portable.ps1','package.manifest.txt','compatibility.json','distribution.json','assets/umbral_ready_guard_post.lua')){$compileArgs+=('/resource:'+(Join-Path $PSScriptRoot $name)+',Omnipotent.Bundle.'+$name)}
& $compiler @compileArgs
if($LASTEXITCODE-ne 0){throw 'No se pudo compilar el launcher.'}
Get-Item -LiteralPath $output|Select-Object FullName,Length
