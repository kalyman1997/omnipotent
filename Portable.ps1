# First-machine preparation. No user data is bundled or downloaded.
$script:CompatibilityHash='a3546bf1f1a4836ce214f2ef39df370984f8521b3ff96b0c4b4f47aaf8367012'
$script:DriverHash='1d06c5edf5b3cf23fca2be1a93831c5c403d6b78d8f0a0663e910affc4dc4e3f'
function Test-CompatibleGame {
    if(![Environment]::Is64BitOperatingSystem){throw 'Omnipotent requiere Windows de 64 bits.'}
    $catalog=Join-Path $PSScriptRoot 'compatibility.json'
    if((Hash-File $catalog) -ne $script:CompatibilityHash){throw 'La lista de compatibilidad fue modificada.'}
    $profile=Get-Content -LiteralPath $catalog -Raw | ConvertFrom-Json
    foreach($file in $profile.Files){
        $path=Resolve-Record $file.Path
        if(![IO.File]::Exists($path)){throw ('Faltan los datos originales de Zombies: '+$file.Path+'. Instala el juego completo antes de continuar.')}
        if((Get-Item -LiteralPath $path).Length -ne $file.Length -or (Hash-File $path) -ne $file.Hash){throw ('Esta version del juego no coincide con la probada: '+$file.Path+'. No se modificaron sus archivos.')}
    }
    $null=Get-AssetsLocation
}
function Get-AssetsLocation {
    $local=Join-Path $script:Root 'xpak_cache'
    $shared=Join-Path ([IO.Path]::GetDirectoryName($script:Root)) 'xpak_cache'
    Assert-NoLink $shared
    if(Test-Path -LiteralPath $local){
        $item=Get-Item -LiteralPath $local -Force
        if(!$item.PSIsContainer){throw 'xpak_cache debe ser una carpeta de datos del juego.'}
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){
            if($item.LinkType -ne 'Junction' -or @($item.Target).Count -ne 1 -or ![IO.Path]::GetFullPath([string]$item.Target[0]).Equals([IO.Path]::GetFullPath($shared),[StringComparison]::OrdinalIgnoreCase)){throw 'El enlace xpak_cache apunta a otra carpeta. Se conserva sin cambios.'}
            $source=$shared
        }else{Assert-NoLink $local;$source=$local}
    }else{$source=$shared}
    if(![IO.Directory]::Exists($source) -or !@(Get-ChildItem -LiteralPath $source -Filter '*.xpak' -File | Select-Object -First 1).Count){throw 'Faltan los assets xpak del juego completo. Omnipotent no los descarga.'}
    return $source
}
function Test-LocalId($Value){
    [UInt64]$parsed=0
    return [UInt64]::TryParse([string]$Value,[ref]$parsed) -and $parsed -ge [UInt64]76561197960265728 -and $parsed -le [UInt64]76561202255233023
}
function Ensure-LocalProfile {
    $settings=Resolve-Record 'kronos\settings.json';$identity=Resolve-Record 'steam_settings\force_steamid.txt'
    $config=if([IO.File]::Exists($settings)){Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json}else{[pscustomobject]@{version=1;player=[pscustomobject]@{name='Player';xuid=0}}}
    if(!$config -or $config -is [Array] -or $config -is [string]){throw 'La configuracion local no es valida. Se conserva sin cambios.'}
    if(!$config.PSObject.Properties['player']){$config|Add-Member NoteProperty player ([pscustomobject]@{name='Player';xuid=0})}
    if(!$config.player){throw 'El perfil local no es valido.'}
    $steamId=if([IO.File]::Exists($identity)){[IO.File]::ReadAllText($identity).Trim()}else{''}
    if(Test-LocalId $steamId){$id=[UInt64]$steamId}
    elseif(Test-LocalId $config.player.xuid){$id=[UInt64]$config.player.xuid}
    else{$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$bytes=New-Object byte[] 4;$rng.GetBytes($bytes);$id=[UInt64]76561197960265728+[BitConverter]::ToUInt32($bytes,0)}finally{$rng.Dispose()}}
    $before=@(Take-Snapshot @('kronos\settings.json','steam_settings\force_steamid.txt'))
    Write-JsonAtomic (Join-Path $script:Store 'profile-before.json') @{Files=$before;GamePath=$script:Root}
    if(!$config.player.PSObject.Properties['xuid']){$config.player|Add-Member NoteProperty xuid $id}
    else{$config.player.xuid=$id}
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($settings))|Out-Null
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($identity))|Out-Null
    Write-JsonAtomic $settings $config
    $temp=$identity+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
    try{
        [IO.File]::WriteAllText($temp,[string]$id,[Text.UTF8Encoding]::new($false))
        if([IO.File]::Exists($identity)){[UmbralAtomic]::Replace($temp,$identity)}else{[IO.File]::Move($temp,$identity)}
    }finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
    $updated=@(Take-Snapshot @('kronos\settings.json','steam_settings\force_steamid.txt'))
    $script:State.Paths=@(@($script:State.Paths)+@($updated.Path)|Sort-Object -Unique)
    $script:State.Offline=@($script:State.Offline|Where-Object{$_.Path -notin $updated.Path})+$updated
    Save-State
}
function Test-DriverRegistration {
    $driver=Resolve-Record '@content/Randgrid.sys'
    if(![IO.File]::Exists($driver) -or (Hash-File $driver) -ne $script:DriverHash){throw 'El controlador no coincide con el paquete verificado.'}
    $svc=Get-Service -Name 'lumen_randgrid_sat' -ErrorAction SilentlyContinue
    if(!$svc){return $false}
    $key=Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\lumen_randgrid_sat'
    $path=([string]$key.ImagePath).Replace('\??\','').Trim('"')
    if($key.Type -ne 1 -or $key.Start -ne 3 -or ![IO.Path]::GetFullPath($path).Equals($driver,[StringComparison]::OrdinalIgnoreCase)){throw 'El servicio existente pertenece a otra instalacion. No se modificara.'}
    return $true
}
function Ensure-DriverRegistration {
    if(Test-DriverRegistration){return}
    $driver=Resolve-Record '@content/Randgrid.sys'
    if((Get-AuthenticodeSignature -LiteralPath $driver).Status -ne 'Valid'){throw 'Windows no pudo validar la firma del controlador. No se instalara.'}
    $sc=Join-Path ([Environment]::SystemDirectory) 'sc.exe'
    $result=& $sc create lumen_randgrid_sat 'type=' kernel 'start=' demand 'error=' normal 'binPath=' ('"'+$driver+'"') 2>&1
    if($LASTEXITCODE -ne 0){throw ('No se pudo registrar el servicio del juego: '+($result -join ' '))}
    if(!(Test-DriverRegistration)){throw 'No se pudo comprobar el servicio registrado.'}
    Write-JsonAtomic (Join-Path $script:Store 'service-created.json') @{Name='lumen_randgrid_sat';Path=$driver;Utc=[DateTime]::UtcNow.ToString('o')}
}
function Ensure-PortablePrerequisites {
    $source=Get-AssetsLocation
    $link=Join-Path $script:Root 'xpak_cache'
    if(!(Test-Path -LiteralPath $link)){
        New-Item -ItemType Junction -Path $link -Target $source -ErrorAction Stop|Out-Null
        Write-JsonAtomic (Join-Path $script:Store 'assets-link-created.json') @{Path=$link;Target=$source}
    }
    Ensure-LocalProfile
    Ensure-DriverRegistration
    $null=Test-PortablePrerequisites
}
function Test-PortablePrerequisites {
    $null=Get-AssetsLocation
    if(!(Test-Path -LiteralPath (Join-Path $script:Root 'xpak_cache'))){throw 'Falta preparar los assets. Pulsa Instalar.'}
    if(!(Test-DriverRegistration)){throw 'Falta preparar el servicio del juego. Pulsa Instalar.'}
    $settings=Resolve-Record 'kronos\settings.json';$identity=Resolve-Record 'steam_settings\force_steamid.txt'
    if(![IO.File]::Exists($settings) -or ![IO.File]::Exists($identity)){throw 'Falta preparar el perfil local. Pulsa Instalar.'}
    $config=Get-Content -LiteralPath $settings -Raw|ConvertFrom-Json
    $id=[IO.File]::ReadAllText($identity).Trim()
    if(!(Test-LocalId $id) -or [string]$config.player.xuid -ne $id){throw 'El perfil local necesita preparacion. Pulsa Instalar.'}
    return $true
}
