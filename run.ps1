# run.ps1 - Lance l'app Betro sur la tablette en debogage sans fil.
#
# Le port du debogage sans fil change a chaque redemarrage de la tablette,
# ce qui casse "flutter run -d <ip:port>". Ce script redecouvre le port via
# mDNS, reconnecte adb, retire le doublon mDNS qui empeche Flutter de voir
# l'appareil, puis lance l'app.
#
# Usage :
#   .\run.ps1                              lance en mode debug
#   .\run.ps1 --release                    args supplementaires passes a flutter run
#   .\run.ps1 -Target 192.168.95.86:45039  force une cible, sans decouverte

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
        $lines = & $Adb mdns services
        foreach ($line in $lines) {
            if ($line -match '_adb-tls-connect\._tcp\s+(\d{1,3}(?:\.\d{1,3}){3}:\d+)') {
                return $Matches[1]
            }
        }
        Write-Host "  aucune annonce mDNS (tentative $i/$Retries)"
        Start-Sleep -Seconds 2
    }
    return $null
}

function Get-ConnectedTarget {
    param([string]$Adb)

    foreach ($line in (& $Adb devices)) {
        if ($line -match '^(\d{1,3}(?:\.\d{1,3}){3}:\d+)\s+device\b') { return $Matches[1] }
    }
    return $null
}

# Flutter ne sait pas parser l'entree nommee "adb-XXXX._adb-tls-connect._tcp" et
# abandonne la detection des le moment ou elle est presente, meme si la connexion
# ip:port fonctionne a cote. On la retire systematiquement.
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
    $Target = Get-ConnectedTarget -Adb $adb
    if ($Target) { Write-Host "mDNS muet, reprise de l'appareil deja connecte : $Target" }
}

if (-not $Target) {
    Write-Host ""
    Write-Host "Aucune tablette trouvee." -ForegroundColor Red
    Write-Host "Verifie que :"
    Write-Host "  - le Debogage sans fil est actif (Options developpeur)"
    Write-Host "  - la tablette et le PC sont sur le meme reseau Wi-Fi"
    Write-Host "  - la tablette est deverrouillee"
    Write-Host "Sinon, force la cible : .\run.ps1 -Target 192.168.x.x:PORT"
    exit 1
}

Write-Host "Cible : $Target"
& $adb connect $Target | Write-Host
Remove-MdnsEntries -Adb $adb

if (-not ((& $adb devices) -match [regex]::Escape($Target))) {
    Write-Host "adb n'a pas pu se connecter a $Target." -ForegroundColor Red
    Write-Host "Le port a probablement change entre-temps : relance le script."
    exit 1
}

Write-Host ""
& flutter run -d $Target @args
exit $LASTEXITCODE
