# adb-reconnect.ps1 - Reconnecte la tablette en debogage sans fil, sans lancer l'app.
#
# A utiliser avec VS Code : la tache "Tablette : reconnecter" appelle ce script,
# puis F5 lance l'app normalement. Contrairement a run.ps1 (racine du projet),
# ce script ne demarre pas "flutter run" : c'est le debogueur VS Code qui le fait.

param(
    [string]$Target,
    [int]$DiscoveryRetries = 5
)

$ErrorActionPreference = 'Stop'

function Find-Adb {
    $cmd = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'),
        (Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'),
        'C:\Program Files (x86)\Android\android-sdk\platform-tools\adb.exe'
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    throw "adb.exe introuvable. Ajoute platform-tools au PATH."
}

# Le service mDNS _adb-tls-connect._tcp annonce l'ip:port courant de la tablette.
function Get-WirelessTarget {
    param([string]$Adb, [int]$Retries)

    for ($i = 1; $i -le $Retries; $i++) {
        foreach ($line in (& $Adb mdns services)) {
            if ($line -match '_adb-tls-connect\._tcp\s+(\d{1,3}(?:\.\d{1,3}){3}:\d+)') {
                return $Matches[1]
            }
        }
        Write-Host "  aucune annonce mDNS (tentative $i/$Retries)"
        Start-Sleep -Seconds 2
    }
    return $null
}

# Flutter ne sait pas parser l'entree nommee "adb-XXXX._adb-tls-connect._tcp" et
# abandonne la detection des qu'elle est presente, meme si la connexion ip:port
# fonctionne a cote. On la retire systematiquement.
function Remove-MdnsEntries {
    param([string]$Adb)

    foreach ($line in (& $Adb devices)) {
        if ($line -match '^(adb-\S*_adb-tls-connect\._tcp)\s+device\b') {
            & $Adb disconnect $Matches[1] | Out-Null
            Write-Host "  doublon mDNS retire : $($Matches[1])"
        }
    }
}

$adb = Find-Adb

if (-not $Target) {
    Write-Host "Recherche de la tablette..."
    $Target = Get-WirelessTarget -Adb $adb -Retries $DiscoveryRetries
}

if (-not $Target) {
    Write-Host ""
    Write-Host "Aucune tablette trouvee." -ForegroundColor Red
    Write-Host "Verifie que :"
    Write-Host "  - le Debogage sans fil est actif (Options developpeur)"
    Write-Host "  - la tablette et le PC sont sur le meme reseau Wi-Fi"
    Write-Host "  - la tablette est deverrouillee"
    Write-Host "Sinon, force la cible : .\scripts\adb-reconnect.ps1 -Target 192.168.x.x:PORT"
    exit 1
}

Write-Host "Cible : $Target"
& $adb connect $Target | Write-Host
Remove-MdnsEntries -Adb $adb

if (-not ((& $adb devices) -match [regex]::Escape($Target))) {
    Write-Host "adb n'a pas pu se connecter a $Target." -ForegroundColor Red
    Write-Host "Le port a probablement change entre-temps : relance la tache."
    exit 1
}

Write-Host ""
Write-Host "Tablette prete. Selectionne-la en bas a droite dans VS Code, puis F5." -ForegroundColor Green
exit 0
