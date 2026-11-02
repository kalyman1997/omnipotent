# Loaded by Hybrid.ps1; uses its validated paths, lock, object store and journal.
function Get-PackageRecords {
    $manifest=Join-Path $PSScriptRoot 'package.manifest.txt'
    if((Hash-File $manifest) -ne $script:KnownManifestHash){throw 'El manifiesto incluido no coincide con la version revisada.'}
    $seen=@{}; $records=@(foreach($line in Get-Content -LiteralPath $manifest){
        if($line -notmatch '^f\s'){continue}
        $v=$line -split "`t"
        if($v.Count-ne 5 -or $v[1]-notin @('exe','mod','srv') -or $v[2]-notmatch '^[a-f0-9]{64}$' -or $v[3]-notmatch '^\d+$'){throw 'Registro de paquete invalido.'}
        if($v[4].StartsWith('cod25/')){$relative=$v[4].Substring(6).Replace('/','\')}
        elseif($v[4] -in @('Randgrid.sys','steam_api64.dll')){$relative='@content/'+$v[4]}
        else{throw 'Ruta de paquete no admitida.'}
        $null=Resolve-Record $relative
        if($seen.ContainsKey($relative)){throw 'Ruta duplicada en paquete.'};$seen[$relative]=$true
        [pscustomobject]@{Path=$relative;Hash=$v[2];Length=[long]$v[3];RemotePath=$v[4]}
    })
    if($records.Count-ne 439){throw 'El paquete revisado debe contener 439 archivos.'}
    return $records
}
function Test-PackageFile($Path,$Record) {
    return [IO.File]::Exists($Path) -and (Get-Item -LiteralPath $Path).Length-eq $Record.Length -and (Hash-File $Path)-eq $Record.Hash
}
function Receive-PackageFile($Record,$Destination) {
    if($Record.Hash -notmatch '^[a-f0-9]{64}$'){throw 'Hash de descarga invalido.'}
    $config=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'distribution.json') -Raw | ConvertFrom-Json
    $base=[Uri]$config.downloadBaseUrl
    if($config.schema -ne 1 -or !$base.IsAbsoluteUri -or $base.Scheme -ne 'https' -or $base.UserInfo -or $base.Query -or $base.Fragment -or !$base.AbsoluteUri.EndsWith('/')){throw 'La direccion de descarga debe ser HTTPS y terminar en /.'}
    [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $client=New-Object Net.WebClient
    $client.Headers['User-Agent']='Omnipotent/1.0'
    try {
        for($attempt=1;$attempt -le 3;$attempt++){
            try{$client.DownloadFile(([Uri]::new($base,$Record.Hash)).AbsoluteUri,$Destination);return}
            catch{if($attempt -eq 3){throw 'No se pudo descargar el paquete de Omnipotent. Comprueba internet y que la release este publicada.'};Start-Sleep -Milliseconds (500*$attempt)}
        }
    }finally{$client.Dispose()}
}
function Prepare-OfflinePackage {
    Assert-Idle
    $records=@(Get-PackageRecords); $cached=0; $imported=0; $downloaded=0
    $done=0
    foreach($record in $records){
        Send-AppProgress (10+[int](40*$done/$records.Count)) ('Preparando archivos · '+$done+'/'+$records.Count)
        $done++
        $dest=Object-Path $record.Hash
        if(Test-PackageFile $dest $record){$cached++;continue}
        if(Test-Path -LiteralPath $dest){throw 'Copia local corrupta. Se conserva para diagnostico; no se instalara.'}
        $installed=Resolve-Record $record.Path
        if(Test-PackageFile $installed $record){Ensure-Object $installed $record.Hash;$imported++;continue}
        $temp=$dest+'.download-'+[Guid]::NewGuid().ToString('N')+'.tmp'
        try {
            Receive-PackageFile $record $temp
            if(-not(Test-PackageFile $temp $record)){throw ('Descarga no verificada: '+$record.Path)}
            [IO.File]::Move($temp,$dest);$downloaded++
        } finally {if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
    }
    Ensure-Object (Join-Path $PSScriptRoot 'package.manifest.txt') $script:KnownManifestHash
    return "Paquete listo: $($records.Count) archivos; $cached en respaldo, $imported importados, $downloaded descargados."
}
function Test-InstalledPackage {
    $checked=0;$records=@(Get-PackageRecords)
    foreach($record in $records){
        if($Action -eq 'InstallSimple'){Send-AppProgress (90+[int](9*$checked/$records.Count)) ('Verificando archivos · '+$checked+'/'+$records.Count)}
        if(-not(Test-PackageFile (Resolve-Record $record.Path) $record)){throw ('Archivo del paquete ausente o distinto: '+$record.Path+'. Usa Instalar / reparar offline.')}
        $checked++
    }
    return $true
}
function Install-OfflinePackage {
    Assert-Idle; Assert-DriverStopped
    if($script:State -and $script:State.Mode -notin @('Offline','OfflineBackedUp','InstallPrepared')){throw 'Usa Activar offline para cambiar desde una base online registrada.'}
    $prepared=Prepare-OfflinePackage
    $records=@(Get-PackageRecords)
    $manifest=Join-Path $PSScriptRoot 'package.manifest.txt'
    $records+=[pscustomobject]@{Path='kronos\launcher_manifest.txt';Hash=$script:KnownManifestHash;Length=(Get-Item $manifest).Length}
    $paths=@($records | ForEach-Object {$_.Path})
    if($script:State){$paths+=@($script:State.Paths)}
    foreach($sub in @('kronos','steam_settings','players')){$paths+=@(Get-RelativeFiles $sub)}
    $paths=@($paths | Sort-Object -Unique)
    Send-AppProgress 55 'Guardando respaldo…'
    $before=@(Take-Snapshot $paths)
    if(-not $script:State){
        $script:State=[pscustomobject]@{Schema=1;GamePath=$script:Root;Mode='InstallPrepared';CreatedUtc=[DateTime]::UtcNow.ToString('o');Paths=$paths;Offline=$before;Online=@();XboxRepairConfirmedUtc=$null}
        Save-State
    }
    $map=@{};foreach($record in $records){$map[$record.Path]=$record}
    $desired=@(foreach($old in $before){if($map.ContainsKey($old.Path)){$map[$old.Path]}else{$old}})
    $changed=@();$preimages=@()
    for($i=0;$i-lt $before.Count;$i++){if($before[$i].Hash-ne $desired[$i].Hash){$changed+=$desired[$i];$preimages+=$before[$i]}}
    $next=$script:State | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $next.Paths=$paths;$next.Offline=$desired
    $mode=if($script:State.Mode-eq 'Offline'){'Offline'}else{'OfflineBackedUp'}
    if($changed.Count){
        # Durable undo exists before writes. Recovery also works after interruption.
        $receipt=[pscustomobject]@{Schema=1;GamePath=$script:Root;PreviousMode=$script:State.Mode;TargetMode=$mode;PreviousState=$script:State;Before=$preimages;Desired=$changed}
        $history=Join-Path $script:Store ('package-install-'+[Guid]::NewGuid().ToString('N')+'.json')
        Write-JsonAtomic $history $receipt
        Write-JsonAtomic (Join-Path $script:Store 'package-restore.json') $receipt
        Send-AppProgress 70 'Instalando archivos offline…'
        Transition-To $changed $mode $next
    }else{$script:State=$next;$script:State.Mode=$mode;Save-State}
    $null=Test-InstalledPackage
    return "$prepared Instalacion verificada: 439/439; archivos sustituidos: $($changed.Count). Puedes jugar sin abrir Kronos."
}
function Install-SimpleOffline {
    Assert-Idle; Assert-DriverStopped
    Test-CompatibleGame
    Send-AppProgress 0 'Preparando instalación…'
    if([IO.File]::Exists((Join-Path $script:Store 'transaction.json'))){Recover-Transaction}
    if($script:State -and $script:State.Mode -in @('Online','NeedsXboxRepair')){Send-AppProgress 5 'Restaurando archivos offline…';Switch-ToOffline}
    $message=Install-OfflinePackage
    Ensure-ReadyGuard
    Ensure-PortablePrerequisites
    Send-AppProgress 100 'Instalación completa.'
    return $message
}
function Restore-OfflinePackage {
    Assert-Idle;Assert-DriverStopped
    if($script:State.Mode-notin @('Offline','OfflineBackedUp','InstallPrepared')){throw 'No se restaura un paquete desde modo online.'}
    $receipt=Join-Path $script:Store 'package-restore.json'
    if(-not [IO.File]::Exists($receipt)){throw 'No hay una instalacion de paquete que deshacer.'}
    $data=Get-Content -LiteralPath $receipt -Raw | ConvertFrom-Json
    if($data.GamePath-ne $script:Root){throw 'El respaldo pertenece a otro juego.'}
    # Validate every current target before creating a recovery journal.
    Verify-Snapshot $data.Desired
    Write-JsonAtomic (Join-Path $script:Store 'transaction.json') $data
    Recover-Transaction
    [IO.File]::Delete($receipt)
}
