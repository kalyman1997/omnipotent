$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'No se encontró el compilador de .NET Framework 4.x.' }
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /utf8output /reference:System.Core.dll /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Xml.dll /reference:System.Web.Extensions.dll /reference:Microsoft.CSharp.dll "/win32manifest:$PSScriptRoot\launcher.manifest" "/out:$PSScriptRoot\Omnipotent.Launcher.exe" "$PSScriptRoot\Launcher.cs" "$PSScriptRoot\Interface.cs" "$PSScriptRoot\Bundle.cs" "$PSScriptRoot\GameDiscovery.cs"
if ($LASTEXITCODE -ne 0) { throw 'La compilación falló.' }
Write-Output 'Compilado: Omnipotent.Launcher.exe (1.0)'
