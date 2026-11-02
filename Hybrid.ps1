param(
    [ValidateSet('Status','BackupOffline','PrepareOnline','CaptureOnline','SwitchOffline','SwitchOnline','Recover','LaunchOffline','PreparePackage','InstallPackage','VerifyPackage','RestorePackage','InstallSimple','InspectSimple')]
    [string]$Action = 'Status',
    [string]$GamePath = 'D:\XboxGames\Call of Duty_1\Content\cod25',
    [string]$StorePath = "$PSScriptRoot\data",
    [switch]$ConfirmXboxRepair,
    [switch]$LibraryOnly,
    [switch]$ReportProgress
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$script:KnownManifestHash = '55926f6089b8a8362755e84a9094dd95358726237b9a10e893e0c98def58d8e0'
$script:KnownExeHash = 'b0b12b0e7ec25ce855ea6e9d042fc8f390b8d48097cb10e0899e8334f35b6db8'
$script:KnownDllHash = '874bcfe491a408bd6f9c75c95ff636ba35536e8eb95f6b2d0ba772f082a8a365'
$script:KnownReadyGuardHash = '4cfd5562bb99d6f79a91bbc8aef2eaa89940ed88ad23a1c0527140dc80a4b4d2'
$script:ReadyGuardSource = Join-Path $PSScriptRoot 'assets\umbral_ready_guard_post.lua'
$script:State = $null
function Send-AppProgress([int]$Value,[string]$Message) {
    if($ReportProgress){[Console]::WriteLine('@progress '+(@{value=$Value;message=$Message}|ConvertTo-Json -Compress))}
}
if (-not ('UmbralAtomic' -as [type])) {
    Add-Type -TypeDefinition @'
using System.IO;
public static class UmbralAtomic {
    public static void Replace(string source, string destination) {
        File.Replace(source, destination, null);
    }
}
'@
}

function Hash-File([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Assert-NoLink([string]$Path) {
    $p = [IO.Path]::GetFullPath($Path)
    while ($p) {
        if (Test-Path -LiteralPath $p) {
            if ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "No se admiten enlaces ni junctions: $p"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($p)
        if ($parent -eq $p) { break }; $p = $parent
    }
}
function Resolve-Leaf([string]$Root, [string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or $Relative -match '(^[\\/]|:|[<>"|?*]|(^|[\\/])\.\.?([\\/]|$))') {
        throw "Ruta relativa rechazada: $Relative"
    }
    foreach ($segment in ($Relative -split '[\\/]')) {
        if (!$segment -or $segment -match '[ .]$' -or $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)') { throw 'Componente de ruta no valido.' }
    }
    $base = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath([IO.Path]::Combine($base,$Relative))
    if (!$full.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)) { throw 'Ruta fuera de la carpeta autorizada.' }
    Assert-NoLink $full
    return $full
}
function Write-JsonAtomic([string]$Path, $Value) {
    $temp = $Path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    [IO.File]::WriteAllText($temp,($Value | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
    if ([IO.File]::Exists($Path)) { [UmbralAtomic]::Replace($temp,$Path) }
    else { [IO.File]::Move($temp,$Path) }
}
function Resolve-Record([string]$Relative) {
    # Two files in the pinned manifest live in Content, above cod25.
    # This explicit namespace never accepts arbitrary parent traversal.
    if ($Relative.StartsWith('@content/',[StringComparison]::OrdinalIgnoreCase)) {
        if ($Relative -notin @('@content/Randgrid.sys','@content/steam_api64.dll')) { throw 'Archivo Content fuera de la lista permitida.' }
        return Resolve-Leaf ([IO.Path]::GetDirectoryName($script:Root)) $Relative.Substring(9)
    }
    return Resolve-Leaf $script:Root $Relative
}
function Save-State { Write-JsonAtomic (Join-Path $script:Store 'state.json') $script:State }
function Object-Path([string]$Hash) {
    if ($Hash -notmatch '^[a-f0-9]{64}$') { throw 'Hash de respaldo invalido.' }
    return Resolve-Leaf $script:Store ('objects\'+$Hash)
}
function Ensure-Object([string]$Source,[string]$Hash) {
    $dest = Object-Path $Hash
    if ([IO.File]::Exists($dest)) {
        if ((Hash-File $dest) -ne $Hash) { throw "Respaldo corrupto: $Hash" }
        return
    }
    $tmp = $dest + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    [IO.File]::Copy($Source,$tmp,$false)
    if ((Hash-File $tmp) -ne $Hash) { throw "El archivo cambio durante el respaldo: $Source" }
    [IO.File]::Move($tmp,$dest)
}
function Assert-Idle {
    $busy = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^(cod|cod25-cod|cod26-cod|KronosLauncher|bootstrapper|gamelaunchhelper)$' })
    if ($busy.Count) { throw ('Cierra el juego y Kronos antes de alternar: '+ (($busy.ProcessName | Sort-Object -Unique) -join ', ')) }
}
function Assert-DriverStopped {
    $svc = Get-Service -Name 'lumen_randgrid_sat' -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Stopped') { throw 'El controlador offline sigue activo. Cierra el juego y reinicia Windows antes de preparar online.' }
}
function Get-RelativeFiles([string]$Sub) {
    $dir = Resolve-Leaf $script:Root $Sub
    if (![IO.Directory]::Exists($dir)) { return }
    # Enumerate one directory at a time; never traverse a junction.
    $queue = New-Object 'Collections.Generic.Queue[string]'
    $queue.Enqueue($dir)
    while ($queue.Count) {
        $current = $queue.Dequeue()
        foreach ($item in Get-ChildItem -LiteralPath $current -Force) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Enlace no admitido: $($item.FullName)" }
            if ($item.PSIsContainer) { $queue.Enqueue($item.FullName) }
            else { $item.FullName.Substring($script:Root.Length+1) }
        }
    }
}
function Get-ManagedPaths {
    $paths = @($script:State.Paths)
    foreach ($sub in @('kronos','steam_settings','players')) { $paths += @(Get-RelativeFiles $sub) }
    return @($paths | Sort-Object -Unique)
}
function Take-Snapshot([string[]]$Paths) {
    $result = @()
    foreach ($rel in $Paths) {
        $full = Resolve-Record $rel
        if ([IO.Directory]::Exists($full)) { throw "Se esperaba un archivo: $rel" }
        $hash = $null; $length = 0L
        if ([IO.File]::Exists($full)) {
            $hash = Hash-File $full
            $length = (Get-Item -LiteralPath $full).Length
            Ensure-Object $full $hash
        }
        $result += [pscustomobject]@{Path=$rel;Hash=$hash;Length=$length}
    }
    return $result
}
function Verify-Snapshot($Snapshot) {
    foreach ($record in $Snapshot) {
        $full = Resolve-Record $record.Path
        if ($record.Hash) {
            if (![IO.File]::Exists($full) -or (Hash-File $full) -ne $record.Hash) { throw "Archivo modificado desde el estado guardado: $($record.Path). No se sobrescribira." }
        } elseif (Test-Path -LiteralPath $full) { throw "Aparecio un archivo no previsto: $($record.Path). No se sobrescribira." }
    }
}
function Apply-Record($Record) {
    $full = Resolve-Record $Record.Path
    if ($Record.Hash) {
        $source = Object-Path $Record.Hash
        if (![IO.File]::Exists($source) -or (Hash-File $source) -ne $Record.Hash) { throw "Respaldo ausente o corrupto: $($Record.Path)" }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
        $temp = $full + '.umbral-' + [Guid]::NewGuid().ToString('N') + '.tmp'
        [IO.File]::Copy($source,$temp,$false)
        if ((Hash-File $temp) -ne $Record.Hash) { throw "Copia no verificada: $($Record.Path)" }
        if ([IO.File]::Exists($full)) { [UmbralAtomic]::Replace($temp,$full) }
        else { [IO.File]::Move($temp,$full) }
    } else {
        if ([IO.Directory]::Exists($full)) { throw "No se eliminan carpetas: $($Record.Path)" }
        if ([IO.File]::Exists($full)) { [IO.File]::Delete($full) }
    }
}
function Transition-To($Desired,[string]$Mode,$NewState=$null) {
    Assert-Idle
    if ($Mode -ne 'Offline') { Assert-DriverStopped }
    $desiredArray = @($Desired)
    # Verify every backup before the first installation write.
    foreach ($r in $desiredArray) {
        $null = Resolve-Record $r.Path
        if ($r.Hash) {
            $obj = Object-Path $r.Hash
            if (![IO.File]::Exists($obj) -or (Hash-File $obj) -ne $r.Hash) { throw "Respaldo ausente o corrupto: $($r.Path)" }
        }
    }
    $before = @(Take-Snapshot @($desiredArray | ForEach-Object {$_.Path}))
    $journal = [pscustomobject]@{Schema=1;GamePath=$script:Root;PreviousMode=$script:State.Mode;TargetMode=$Mode;Before=$before;Desired=$desiredArray;PreviousState=$script:State}
    $journalPath = Join-Path $script:Store 'transaction.json'
    Write-JsonAtomic $journalPath $journal
    try {
        # Recheck immediately before each write so concurrent changes are not silently lost.
        for ($i=0; $i -lt $desiredArray.Count; $i++) {
            Verify-Snapshot @($before[$i])
            Apply-Record $desiredArray[$i]
        }
        Verify-Snapshot $desiredArray
        if($NewState){$script:State=$NewState}
        $script:State.Mode = $Mode
        Save-State
        [IO.File]::Delete($journalPath)
    } catch {
        # Keep the durable journal; Recover checks conflicts before restoring.
        throw ('Cambio incompleto. Usa Recuperar antes de jugar. '+$_.Exception.Message)
    }
}
function Recover-Transaction {
    Assert-Idle; Assert-DriverStopped
    $path = Join-Path $script:Store 'transaction.json'
    if (![IO.File]::Exists($path)) { throw 'No existe una transaccion pendiente.' }
    $j = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($j.GamePath -ne $script:Root) { throw 'La transaccion pertenece a otra instalacion.' }
    # Allow only the pre-operation or desired hash; any third-party edit blocks recovery.
    for ($i=0; $i -lt $j.Before.Count; $i++) {
        $a=$j.Before[$i]; $b=$j.Desired[$i]
        if ($a.Path -ne $b.Path) { throw 'Transaccion inconsistente.' }
        $full = Resolve-Record $a.Path
        $current = $null
        if ([IO.File]::Exists($full)) { $current=Hash-File $full }
        if ($current -ne $a.Hash -and $current -ne $b.Hash) { throw "Cambio externo detectado: $($a.Path). Se conservan los respaldos." }
        if ($a.Hash -and (Hash-File (Object-Path $a.Hash)) -ne $a.Hash) { throw 'Respaldo de recuperacion corrupto.' }
    }
    for ($i=0; $i -lt $j.Before.Count; $i++) {
        $a=$j.Before[$i]; $b=$j.Desired[$i]; $full=Resolve-Record $a.Path; $current=$null
        if ([IO.File]::Exists($full)) {$current=Hash-File $full}
        if ($current -ne $a.Hash -and $current -ne $b.Hash) {throw "Cambio externo durante recuperacion: $($a.Path)"}
        Apply-Record $a
    }
    Verify-Snapshot $j.Before
    if($j.PreviousState){$script:State=$j.PreviousState}
    $script:State.Mode=$j.PreviousMode; Save-State
    [IO.File]::Delete($path)
}
function Initialize-Offline {
    Assert-Idle
    if ($script:State) { throw 'Ya existe un respaldo para esta instalacion.' }
    $manifest=Resolve-Leaf $script:Root 'kronos\launcher_manifest.txt'
    if ((Hash-File $manifest) -ne $script:KnownManifestHash) { throw 'Version del manifiesto no reconocida. Requiere revisar los cambios antes de importar.' }
    if ((Hash-File (Resolve-Leaf $script:Root 'cod25-cod.exe')) -ne $script:KnownExeHash) { throw 'El ejecutable no coincide con la version offline analizada.' }
    if ((Hash-File (Resolve-Leaf $script:Root 'XINPUT9_1_0.dll')) -ne $script:KnownDllHash) { throw 'La DLL no coincide con la version offline analizada.' }
    $paths=@()
    foreach ($line in Get-Content -LiteralPath $manifest) {
        if ($line -notmatch '^f\s') { continue }
        $v=$line -split "`t"
        if ($v.Count -ne 5 -or $v[1] -notin @('exe','mod','srv')) { throw 'Entrada no admitida en el manifiesto.' }
        if ($v[4] -match '^cod25/') { $rel=$v[4].Substring(6).Replace('/','\') }
        elseif ($v[4] -in @('Randgrid.sys','steam_api64.dll')) { $rel='@content/'+$v[4] }
        else { throw 'Ruta del manifiesto fuera del alcance autorizado.' }
        $null=Resolve-Record $rel
        $paths+=$rel
    }
    foreach ($sub in @('kronos','steam_settings','players')) { $paths+=@(Get-RelativeFiles $sub) }
    $paths=@($paths | Sort-Object -Unique)
    $snapshot=@(Take-Snapshot $paths)
    if (@($snapshot | Where-Object {!$_.Hash}).Count) { throw 'Faltan archivos del paquete offline. No se modifica el juego.' }
    $script:State=[pscustomobject]@{Schema=1;GamePath=$script:Root;Mode='OfflineBackedUp';CreatedUtc=[DateTime]::UtcNow.ToString('o');Paths=$paths;Offline=$snapshot;Online=@();XboxRepairConfirmedUtc=$null}
    Save-State
}
function Capture-Online {
    Assert-Idle; Assert-DriverStopped
    if (!$ConfirmXboxRepair) { throw 'Confirma que Xbox completo Verificar y reparar antes de registrar este estado.' }
    if ($script:State.Mode -notin @('NeedsXboxRepair','Online')) { throw 'Primero prepara online y repara desde Xbox.' }
    if (![IO.File]::Exists((Resolve-Leaf $script:Root 'cod25-cod.exe'))) { throw 'Xbox aun no ha restaurado cod25-cod.exe.' }
    foreach ($rel in @('XINPUT9_1_0.dll','steam_api64_gb.dll','steam_appid.txt')) {
        if ([IO.File]::Exists((Resolve-Leaf $script:Root $rel))) { throw "Sigue presente un archivo offline: $rel. No se registra online." }
    }
    $paths=@(Get-ManagedPaths)
    $script:State.Online=@(Take-Snapshot $paths)
    $script:State.Paths=$paths
    $script:State.Mode='Online'
    $script:State.XboxRepairConfirmedUtc=[DateTime]::UtcNow.ToString('o')
    Save-State
}
function Switch-ToOffline {
    if ($script:State.Mode -eq 'NeedsXboxRepair') {
        # Abort first-time online setup without losing the saved offline installation.
        Transition-To @($script:State.Offline) 'OfflineBackedUp'
        return
    }
    if ($script:State.Mode -ne 'Online') { throw 'Para activar offline primero registra la reparacion de Xbox.' }
    Assert-Idle
    # Game-owned configuration may legitimately change after an online session.
    Verify-Snapshot @($script:State.Online | Where-Object {$_.Path -notmatch '^(players)[\\/]'})
    $paths=@(Get-ManagedPaths)
    $script:State.Online=@(Take-Snapshot $paths); $script:State.Paths=$paths; Save-State
    $map=@{}; foreach($r in $script:State.Offline){$map[$r.Path]=$r}
    $desired=@(foreach($p in $paths){if($map.ContainsKey($p)){$map[$p]}else{[pscustomobject]@{Path=$p;Hash=$null;Length=0}}})
    Transition-To $desired 'Offline'
}
function Switch-ToOnline {
    if ($script:State.Mode -notin @('Offline','OfflineBackedUp')) { throw 'El estado actual no es offline.' }
    if (!$script:State.Online.Count) { throw 'Todavia falta la primera reparacion de Xbox.' }
    Assert-Idle; Assert-DriverStopped
    Verify-Snapshot @($script:State.Offline | Where-Object {$_.Path -notmatch '^(kronos|players|steam_settings)[\\/]'})
    $paths=@(Get-ManagedPaths)
    $script:State.Offline=@(Take-Snapshot $paths); $script:State.Paths=$paths; Save-State
    $map=@{}; foreach($r in $script:State.Online){$map[$r.Path]=$r}
    $desired=@(foreach($p in $paths){if($map.ContainsKey($p)){$map[$p]}else{[pscustomobject]@{Path=$p;Hash=$null;Length=0}}})
    Transition-To $desired 'Online'
}
function Ensure-ReadyGuard {
    Assert-Idle
    Assert-NoLink $script:ReadyGuardSource
    if ((Hash-File $script:ReadyGuardSource) -ne $script:KnownReadyGuardHash) { throw 'La proteccion de preparacion de Zombies no coincide con la version revisada.' }
    $target=Resolve-Leaf $script:Root 'kronos\Assets\Lua\umbral_ready_guard_post.lua'
    if ([IO.File]::Exists($target)) {
        if ((Hash-File $target) -ne $script:KnownReadyGuardHash) { throw 'La proteccion de Zombies fue modificada. No se sobrescribira.' }
        return
    }
    $temp=$target+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
    try {
        [IO.File]::Copy($script:ReadyGuardSource,$temp,$false)
        if ((Hash-File $temp) -ne $script:KnownReadyGuardHash) { throw 'La copia de la proteccion de Zombies no coincide.' }
        # A new extra file only. Move fails if another writer creates the target.
        # Get-ManagedPaths includes it in the next offline backup/online switch.
        [IO.File]::Move($temp,$target)
    } finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}
function Start-OfflineGame {
    Send-AppProgress -1 'Comprobando archivos del juego…'
    if ($script:State.Mode -notin @('Offline','OfflineBackedUp')) { throw 'Activa offline antes de jugar.' }
    Assert-Idle
    Test-CompatibleGame
    $null=Test-PortablePrerequisites
    $null=Test-InstalledPackage
    Verify-Snapshot @($script:State.Offline | Where-Object {$_.Path -notmatch '^(kronos|players|steam_settings)[\\/]'})
    $exe=Resolve-Leaf $script:Root 'cod25-cod.exe'
    $driver=[IO.Path]::Combine([IO.Path]::GetDirectoryName($script:Root),'Randgrid.sys')
    Assert-NoLink $driver
    if (![IO.File]::Exists($driver)) { throw 'Falta Randgrid.sys en la carpeta Content.' }
    $svc=Get-Service -Name 'lumen_randgrid_sat' -ErrorAction SilentlyContinue
    if (!$svc) { throw 'No existe el servicio offline previamente instalado. Este gestor no instala controladores.' }
    $driverImage=(Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\lumen_randgrid_sat' -Name ImagePath).ImagePath
    $driverImage=$driverImage.Replace('\??\','').Trim('"')
    if (![IO.Path]::GetFullPath($driverImage).Equals([IO.Path]::GetFullPath($driver),[StringComparison]::OrdinalIgnoreCase)) { throw 'El servicio apunta a otro controlador. Arranque bloqueado.' }
    Ensure-ReadyGuard
    $started=$false
    $brandingAttempted=$false
    try {
        $brandingAttempted=$true
        Start-BrandingTransaction
        if ($svc.Status -ne 'Running') {
            Start-Service -Name 'lumen_randgrid_sat'; $started=$true
            $svc.WaitForStatus('Running',[TimeSpan]::FromSeconds(15))
        }
        $info=New-Object Diagnostics.ProcessStartInfo
        # Observed working launch chain. Reject cmd expansion/control characters.
        if($exe -match '[%!?^&|<>"\r\n]'){throw 'La ruta contiene caracteres no admitidos para el arranque.'}
        $info.FileName=Join-Path ([Environment]::SystemDirectory) 'cmd.exe'
        $info.WorkingDirectory=[IO.Path]::GetDirectoryName($script:Root)
        $info.Arguments='/d /c start "" /wait "'+$exe+'" hdeyguxs3zaumvlgvybm2vyc'
        $info.UseShellExecute=$false; $info.CreateNoWindow=$true
        $process=[Diagnostics.Process]::Start($info)
        Send-AppProgress -1 'Juego abierto. Disfruta tu partida.'
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "El juego termino con codigo $($process.ExitCode)." }
    } finally {
        try { if ($started) { Stop-Service -Name 'lumen_randgrid_sat' -ErrorAction Continue } }
        finally { if($brandingAttempted -and [IO.File]::Exists((Join-Path $script:Store 'transaction.json'))) { Recover-Transaction } }
    }
}
function Status-Result([bool]$Ok,[string]$Message) {
    $mode='New'; $can=@('Status','BackupOffline','PreparePackage','InstallPackage','VerifyPackage'); $details=@()
    if ($script:State) {
        $mode=$script:State.Mode
        $details+=('Archivos gestionados: '+$script:State.Paths.Count)
        switch($mode) {
            'InstallPrepared' {$can=@('Status','PreparePackage','InstallPackage','VerifyPackage')}
            'OfflineBackedUp' {$can=@('Status','PrepareOnline','LaunchOffline','PreparePackage','InstallPackage','VerifyPackage')}
            'NeedsXboxRepair' {$can=@('Status','CaptureOnline','SwitchOffline')}
            'Online' {$can=@('Status','SwitchOffline','CaptureOnline')}
            'Offline' {$can=@('Status','SwitchOnline','LaunchOffline','PreparePackage','InstallPackage','VerifyPackage')}
        }
    }
    if($mode -in @('Offline','OfflineBackedUp','InstallPrepared') -and [IO.File]::Exists((Join-Path $script:Store 'package-restore.json'))){$can+='RestorePackage'}
    if ([IO.File]::Exists((Join-Path $script:Store 'transaction.json'))) { $mode='RecoveryRequired'; $can=@('Status','Recover') }
    $details+=('Juego: '+$script:Root)
    $details+=('Respaldos: '+$script:Store)
    $details+='Paquete de referencia v1.36: 439 archivos. Preparar reutiliza copias locales y descarga solo los faltantes.'
    $details+='Offline utiliza el componente Kronos existente; online requiere reparacion inicial de Xbox.'
    $details+='El estado guardado no certifica compatibilidad con los servidores ni con el antitrampas.'
    return [pscustomobject]@{ok=$Ok;state=$mode;message=$Message;details=$details;can=$can}
}
function Initialize-Paths {
    foreach($p in @($GamePath,$StorePath)) {
        if ($p -notmatch '^[A-Za-z]:[\\/]' -or $p.StartsWith('\\')) { throw 'Se requieren rutas locales absolutas.' }
        Assert-NoLink $p
    }
    $script:Root=[IO.Path]::GetFullPath($GamePath).TrimEnd('\')
    $script:Store=[IO.Path]::GetFullPath($StorePath).TrimEnd('\')
    if (![IO.Directory]::Exists($script:Root)) { throw 'No existe la carpeta del juego.' }
    if (($script:Store+'\').StartsWith($script:Root+'\',[StringComparison]::OrdinalIgnoreCase) -or ($script:Root+'\').StartsWith($script:Store+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Los respaldos deben quedar fuera de la instalacion.' }
    [IO.Directory]::CreateDirectory($script:Store) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $script:Store 'objects')) | Out-Null
    $file=Join-Path $script:Store 'state.json'
    if ([IO.File]::Exists($file)) {
        $script:State=Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        if ($script:State.Schema -ne 1 -or $script:State.GamePath -ne $script:Root) { throw 'El respaldo pertenece a otra instalacion o version.' }
    }
}
. (Join-Path $PSScriptRoot 'OfflinePackage.ps1')
. (Join-Path $PSScriptRoot 'Branding.ps1')
. (Join-Path $PSScriptRoot 'Portable.ps1')
if ($LibraryOnly) { return }
$lock=$null; $mutex=$null; $ownsMutex=$false
try {
    Initialize-Paths
    $sha=[Security.Cryptography.SHA256]::Create()
    try {$key=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($script:Root.ToUpperInvariant())))).Replace('-','')}finally{$sha.Dispose()}
    $mutex=New-Object Threading.Mutex($false,('Local\UmbralHybrid-'+$key))
    try {$ownsMutex=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException] {$ownsMutex=$true}
    if (!$ownsMutex) {throw 'Otra instancia de Omnipotent esta operando sobre este juego.'}
    $lock=[IO.File]::Open((Join-Path $script:Store 'operation.lock'),'OpenOrCreate','ReadWrite','None')
    if ($Action -notin @('Status','Recover','InstallSimple','InspectSimple') -and [IO.File]::Exists((Join-Path $script:Store 'transaction.json'))) { throw 'Hay un cambio pendiente. Usa Recuperar.' }
    switch($Action) {
        'Status' { $message='Estado guardado. Las operaciones verifican los hashes antes de modificar archivos.' }
        'InspectSimple' {
            $message='Instala el modo offline para comenzar.'
            if($script:State -and $script:State.Mode -in @('Offline','OfflineBackedUp') -and ![IO.File]::Exists((Join-Path $script:Store 'transaction.json'))){Test-CompatibleGame;$null=Test-InstalledPackage;$null=Test-PortablePrerequisites;$message='Instalacion offline comprobada.'}
        }
        'InstallSimple' {
            $message=Install-SimpleOffline
        }
        'BackupOffline' { Initialize-Offline; $message='Respaldo offline verificado. La instalacion no se ha modificado.' }
        'PreparePackage' {$message=Prepare-OfflinePackage}
        'InstallPackage' {$message=Install-OfflinePackage}
        'VerifyPackage' {$null=Test-InstalledPackage;$message='439/439 archivos del paquete coinciden en tamano y SHA256.'}
        'RestorePackage' {Restore-OfflinePackage;$message='Restaurados los archivos anteriores a la ultima instalacion del paquete.'}
        'PrepareOnline' {
            if (!$script:State -or $script:State.Mode -ne 'OfflineBackedUp') { throw 'Primero guarda el respaldo offline.' }
            Assert-Idle; Assert-DriverStopped
            $paths=@(Get-ManagedPaths)
            $script:State.Offline=@(Take-Snapshot $paths); $script:State.Paths=$paths; Save-State
            $empty=@($paths | ForEach-Object {[pscustomobject]@{Path=$_;Hash=$null;Length=0}})
            Transition-To $empty 'NeedsXboxRepair'
            $message='Archivos offline guardados y retirados. Ejecuta Verificar y reparar desde Xbox; despues registra la reparacion.'
        }
        'CaptureOnline' { Capture-Online; $message='Estado reparado por Xbox registrado. Ya se puede alternar.' }
        'SwitchOffline' { Switch-ToOffline; $message='Estado offline restaurado y verificado.' }
        'SwitchOnline' { Switch-ToOnline; $message='Estado online guardado restaurado y verificado. Abre el juego desde Xbox.' }
        'Recover' { Recover-Transaction; $message='Se restauro el estado anterior al cambio interrumpido.' }
        'LaunchOffline' { Start-OfflineGame; $message='La sesion offline ha terminado.' }
    }
    Status-Result $true $message | ConvertTo-Json -Depth 5 -Compress
} catch {
    $msg=$_.Exception.Message
    if ($script:Store -and $script:Root) { Status-Result $false $msg | ConvertTo-Json -Depth 5 -Compress }
    else { [pscustomobject]@{ok=$false;state='Error';message=$msg;details=@();can=@('Status')} | ConvertTo-Json -Compress }
    exit 2
} finally { if ($lock) { $lock.Dispose() }; if($ownsMutex){$mutex.ReleaseMutex()};if($mutex){$mutex.Dispose()} }
