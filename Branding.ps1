# Cosmetic strings only, applied before launch and restored after the game exits.
# The regular transaction journal also handles interrupted launches.
function Start-BrandingTransaction {
    Assert-Idle; Assert-DriverStopped
    $journalPath=Join-Path $script:Store 'transaction.json'
    if ([IO.File]::Exists($journalPath)) { throw 'Primero recupera el cambio pendiente.' }
    $paths=@('XINPUT9_1_0.dll','kronos\launcher_manifest.txt')
    $expected=@($script:KnownDllHash,$script:KnownManifestHash)
    for($i=0;$i -lt $paths.Count;$i++) {
        if((Hash-File (Resolve-Record $paths[$i])) -ne $expected[$i]) { throw ('Version no reconocida para el rotulo: '+$paths[$i]) }
    }
    $before=@(Take-Snapshot $paths)
    $dll=[IO.File]::ReadAllBytes((Object-Path $script:KnownDllHash))
    # REA: VA 0x18015f320, raw offset 0x15dd20, twelve bytes before zm_sat.
    $offset=1432864
    if([BitConverter]::ToString($dll,$offset,12) -ne '4B-72-6F-6E-6F-73-20-25-73-00-00-00') { throw 'El texto de referencia no coincide.' }
    [byte[]]$caption=New-Object byte[] 12
    [Text.Encoding]::ASCII.GetBytes('%s 1.0').CopyTo($caption,0)
    $caption.CopyTo($dll,$offset)
    $manifest=[IO.File]::ReadAllBytes((Object-Path $script:KnownManifestHash))
    $text=[Text.Encoding]::UTF8.GetString($manifest)
    if([regex]::Matches($text,'(?m)^version v1\.36\r?$').Count -ne 1) { throw 'Version de referencia no encontrada.' }
    $text=$text.Replace('version v1.36','version Omnipotent')
    $payloads=@($dll,[Text.Encoding]::UTF8.GetBytes($text))
    $desired=@()
    for($i=0;$i -lt $paths.Count;$i++) {
        $temp=Join-Path $script:Store ('branding-'+[Guid]::NewGuid().ToString('N')+'.tmp')
        try {
            [IO.File]::WriteAllBytes($temp,$payloads[$i])
            $hash=Hash-File $temp
            Ensure-Object $temp $hash
            $desired+=[pscustomobject]@{Path=$paths[$i];Hash=$hash;Length=$payloads[$i].Length}
        } finally { if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)} }
    }
    $journal=[pscustomobject]@{Schema=1;GamePath=$script:Root;PreviousMode=$script:State.Mode;TargetMode=$script:State.Mode;Before=$before;Desired=$desired;PreviousState=$script:State;Purpose='Omnipotent 1.0 caption'}
    Write-JsonAtomic $journalPath $journal
    for($i=0;$i -lt $desired.Count;$i++) { Verify-Snapshot @($before[$i]); Apply-Record $desired[$i] }
    Verify-Snapshot $desired
    Write-JsonAtomic (Join-Path $script:Store 'branding-last.json') @{caption='Omnipotent 1.0';appliedUtc=[DateTime]::UtcNow.ToString('o');files=$desired}
}
