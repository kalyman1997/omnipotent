param([Parameter(Mandatory=$true)][string]$PackagePath,[ValidateSet('Inspect','Stage','Publish')][string]$Mode='Inspect')
$ErrorActionPreference='Stop'
$package=[IO.Path]::GetFullPath($PackagePath)
$inventory=Get-Content -LiteralPath (Join-Path $package 'release-inventory.json') -Raw|ConvertFrom-Json
$repository=[string]$inventory.repository;$tag=[string]$inventory.tag
if($repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -or $tag -notmatch '^[A-Za-z0-9_.-]+$'){throw 'Repositorio no valido.'}
$owner,$name=$repository.Split('/')
# Use the existing Git credential manager session; never save or print its token.
$previousInteractive=$env:GCM_INTERACTIVE;$env:GCM_INTERACTIVE='Never'
try{
    $credential=@("protocol=https`nhost=github.com`nusername=$owner`n`n" | & git credential fill)
    if($LASTEXITCODE-ne 0){throw 'Conecta primero tu cuenta de GitHub con Git Credential Manager.'}
    $secretLine=$credential|Where-Object{$_-like 'password=*'}|Select-Object -First 1
    if(!$secretLine){throw 'No hay credencial de GitHub disponible.'}
    $headers=@{Authorization='Bearer '+$secretLine.Substring(9);Accept='application/vnd.github+json';'X-GitHub-Api-Version'='2022-11-28';'User-Agent'='Omnipotent-Publisher'}
    $credential=$null;$secretLine=$null
    function Api([string]$Method,[string]$Route,$Body=$null){
        $params=@{Method=$Method;Uri=('https://api.github.com/'+$Route);Headers=$headers;TimeoutSec=120}
        if($null-ne $Body){$params.Body=$Body|ConvertTo-Json -Depth 10 -Compress;$params.ContentType='application/json'}
        Invoke-RestMethod @params
    }
    function OptionalGet([string]$Route){try{Api GET $Route}catch{if([int]$_.Exception.Response.StatusCode-eq 404){return $null};throw}}
    $account=Api GET 'user'
    if($account.login-ne $owner){throw 'La cuenta conectada no coincide con el propietario solicitado.'}
    $repo=OptionalGet "repos/$repository"
    if($Mode-eq 'Inspect'){
        [pscustomobject]@{account=$account.login;repositoryExists=($null-ne $repo);repository=$repository;private=if($repo){$repo.private}else{$null};size=if($repo){$repo.size}else{0}}|ConvertTo-Json
        return
    }
    # Verify all outbound files against the prepared inventory before publishing.
    foreach($asset in $inventory.assets){
        if($asset.name-notmatch '^([a-f0-9]{64}|Omnipotent\.exe)$'){throw 'Nombre de asset no permitido.'}
        $file=Join-Path (Join-Path $package 'release-assets') $asset.name
        if((Get-Item -LiteralPath $file).Length-ne $asset.size -or (Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant()-ne $asset.sha256){throw ('Entrega local modificada: '+$asset.name)}
    }
    if(!$repo){
        if($Mode-ne 'Stage'){throw 'Primero prepara la release.'}
        $repo=Api POST 'user/repos' @{name=$name;description='Omnipotent: launcher offline con instalacion verificada y respaldos locales.';private=$false;auto_init=$false;has_wiki=$false;has_projects=$false}
        Write-Output ('Repositorio creado: '+$repo.html_url)
    }
    if($repo.private){throw 'El repositorio es privado. No se cambia su visibilidad automaticamente.'}
    if($Mode-eq 'Stage'){
        $source=Join-Path $package 'repository'
        $gitArgs=@('-c',('safe.directory='+$source.Replace('\','/')),'-C',$source)
        if(!(Test-Path -LiteralPath (Join-Path $source '.git'))){
            & git @gitArgs init --initial-branch=main|Out-Null;if($LASTEXITCODE-ne 0){throw 'git init fallo.'}
        }
        & git @gitArgs config user.name $owner
        if($LASTEXITCODE-ne 0){throw 'No se pudo configurar el autor local.'}
        & git @gitArgs config user.email ($owner+'@users.noreply.github.com')
        & git @gitArgs add -- .
        if($LASTEXITCODE-ne 0){throw 'No se pudo preparar el codigo.'}
        & git @gitArgs diff --cached --quiet
        if($LASTEXITCODE-eq 1){& git @gitArgs commit -m 'Prepare Omnipotent portable launcher and verified installer'|Out-Null;if($LASTEXITCODE-ne 0){throw 'git commit fallo.'}}
        elseif($LASTEXITCODE-ne 0){throw 'No se pudo comprobar el commit.'}
        $expectedRemote='https://github.com/'+$repository+'.git'
        $remoteUrl=& git @gitArgs remote get-url origin 2>$null
        if($LASTEXITCODE-ne 0){& git @gitArgs remote add origin $expectedRemote}
        elseif($remoteUrl-ne $expectedRemote){throw 'El remoto existente apunta a otro repositorio.'}
        & git @gitArgs push -u origin main
        if($LASTEXITCODE-ne 0){throw 'No se pudo publicar el codigo. No se sobrescribe el historial remoto.'}
    }
    $release=OptionalGet "repos/$repository/releases/tags/$tag"
    if(!$release){
        if($Mode-ne 'Stage'){throw 'No existe el borrador de release.'}
        $notes=[IO.File]::ReadAllText((Join-Path $package 'RELEASE-NOTES.txt'))
        $release=Api POST "repos/$repository/releases" @{tag_name=$tag;target_commitish='main';name='Omnipotent 1.0 - primera prueba en otra PC';body=$notes;draft=$true;prerelease=$true}
    }
    $remote=@{};$page=1
    do{$batch=@(Api GET "repos/$repository/releases/$($release.id)/assets?per_page=100&page=$page");foreach($asset in $batch){$remote[$asset.name]=$asset};$page++}while($batch.Count-eq 100)
    $done=0
    foreach($asset in $inventory.assets){
        if($remote.ContainsKey($asset.name)){$uploaded=$remote[$asset.name]}
        elseif($Mode-eq 'Stage' -and $release.draft){
            $file=Join-Path (Join-Path $package 'release-assets') $asset.name
            $uri="https://uploads.github.com/repos/$repository/releases/$($release.id)/assets?name=$([Uri]::EscapeDataString($asset.name))"
            $uploaded=Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -ContentType 'application/octet-stream' -InFile $file -TimeoutSec 3600
        }else{throw ('Falta asset remoto: '+$asset.name)}
        if($uploaded.state-ne 'uploaded' -or $uploaded.size-ne $asset.size -or $uploaded.digest-ne ('sha256:'+$asset.sha256)){throw ('El hash remoto no coincide: '+$asset.name)}
        $done++;if($done%10-eq 0 -or $done-eq $inventory.assets.Count){Write-Output ("Assets verificados: $done/$($inventory.assets.Count)")}
    }
    if($Mode-eq 'Publish' -and $release.draft){$release=Api PATCH "repos/$repository/releases/$($release.id)" @{draft=$false;prerelease=$true}}
    [pscustomobject]@{repository=$repo.html_url;release=$release.html_url;draft=$release.draft;verifiedAssets=$done;launcher="https://github.com/$repository/releases/download/$tag/Omnipotent.exe"}|ConvertTo-Json|Tee-Object -FilePath (Join-Path $package 'publication.json')
}finally{$headers=$null;$credential=$null;$secretLine=$null;$env:GCM_INTERACTIVE=$previousInteractive}
