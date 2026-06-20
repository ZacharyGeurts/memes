# michigan.ps1 v4 — full local security stack (SG) — Windows
#Requires -RunAsAdministrator
param(
    [ValidateSet('All', 'Net', 'Samba', 'Scrub', 'Clipboard', 'Status', 'Help')]
    [string]$Action = 'Help',
    [switch]$Init,          # Clipboard: create vault passphrase
    [switch]$PurgeSamba
)

$ErrorActionPreference = 'Stop'
$Version = 4
$SG = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

function Log([string]$Msg) { Write-Host "[michigan v$Version] $Msg" }

function Show-Help {
    @"
michigan.ps1 v$Version — SG security bundle (run as Administrator)

  .\michigan.ps1 -Action All
  .\michigan.ps1 -Action Net
  .\michigan.ps1 -Action Samba [-PurgeSamba]
  .\michigan.ps1 -Action Scrub
  .\michigan.ps1 -Action Clipboard [-Init]
  .\michigan.ps1 -Action Status

Clipboard daily (after -Action Clipboard -Init):
  . $SG\secure_clipboard.ps1
  scopy 'secret text'
  spaste
  sclear
"@
}

# ── Samba / SMB server off ─────────────────────────────────────────────────
function Invoke-MichiganSamba {
    Log 'stop SMB server (LanmanServer)'
    $server = Get-Service -Name LanmanServer -ErrorAction SilentlyContinue
    if ($server) {
        Stop-Service LanmanServer -Force -ErrorAction SilentlyContinue
        Set-Service LanmanServer -StartupType Disabled
    }
    try {
        Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
    } catch { }
    if ($PurgeSamba) {
        Log 'SMB1 disabled; Server service disabled (no purge API on Windows)'
    }
    Log "LanmanServer: $((Get-Service LanmanServer -EA SilentlyContinue).Status)"
}

# ── Network hardening ──────────────────────────────────────────────────────
function Invoke-MichiganNet {
    Invoke-MichiganSamba

    Log 'disable IPv6 on all adapters'
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | ForEach-Object {
        Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
    }
    $ipv6Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
    if (-not (Test-Path $ipv6Key)) { New-Item -Path $ipv6Key -Force | Out-Null }
    Set-ItemProperty -Path $ipv6Key -Name DisabledComponents -Type DWord -Value 0xFFFFFFFF

    Log 'firewall: deny in, allow out'
    Set-NetFirewallProfile -Profile Domain, Public, Private `
        -DefaultInboundAction Block `
        -DefaultOutboundAction Allow `
        -Enabled True
    Get-NetFirewallRule -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayGroup -match 'File and Printer Sharing' -and $_.Direction -eq 'Inbound' } |
        ForEach-Object { Disable-NetFirewallRule -Name $_.Name -ErrorAction SilentlyContinue }

    Log 'block UP Michigan ISP ranges (best-effort)'
    foreach ($cidr in @('97.95.0.0/16', '66.219.0.0/16')) {
        $name = "Michigan-v4-block-$($cidr.Replace('/','-'))"
        if (-not (Get-NetFirewallRule -DisplayName $name -EA SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $name -Direction Inbound -Action Block `
                -RemoteAddress $cidr -Enabled True -ErrorAction SilentlyContinue | Out-Null
        }
    }

    Log 'verify'
    Get-NetFirewallProfile | Select-Object Name, DefaultInboundAction, DefaultOutboundAction, Enabled |
        Format-Table -AutoSize
}

# ── Scrub Michigan ─────────────────────────────────────────────────────────
function Invoke-MichiganScrub {
    Log "scrub local SG files under $SG"
    $patterns = @(
        @{ Find = ',?\s*Gladstone Michigan'; Repl = '' },
        @{ Find = 'Gladstone, Michigan, USA'; Repl = '' },
        @{ Find = 'come to Michigan and '; Repl = '' },
        @{ Find = 'come to Michigan'; Repl = '' }
    )
    $files = @(
        'README.md', 'submicro.md',
        'AMOURANTHRTX-wiki\Home.md', 'AMOURANTHRTX-wiki\Memoriums.md',
        'ammo\README.md', 'ammo\SG_DEEP_DIVE_BUSINESS_README.md'
    )
    foreach ($rel in $files) {
        $path = Join-Path $SG $rel
        if (-not (Test-Path $path)) { continue }
        $text = Get-Content -Raw -Path $path
        foreach ($p in $patterns) {
            $text = [regex]::Replace($text, $p.Find, $p.Repl, 'IgnoreCase')
        }
        $text = [regex]::Replace($text, '(?m)^- \*\*Location\*\*:.*\r?\n', '')
        Set-Content -Path $path -Value $text -NoNewline
        Log "scrubbed $rel"
    }

    Log 'local grep'
    Get-ChildItem -Path $SG -Recurse -Include *.md,*.ps1,*.sh -ErrorAction SilentlyContinue |
        Select-String -Pattern 'gladstone|49837|burntwood' -CaseSensitive:$false |
        Select-Object -First 10 |
        ForEach-Object { Write-Host "  $($_.Path):$($_.LineNumber)" }
    if (-not $?) { Log 'local clean (or no matches)' }

    Log 'GitHub profile (requires gh auth)'
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            gh auth status 2>$null | Out-Null
            gh api -X PATCH user -f location='Singapore' `
                -f bio='God (1d) is both inside and outside of every dimension. All higher dimension contains both the lower dimensions (including 1) and the highest dimension (1). ¬0 ♠'
            gh api user --jq '{login,location,bio}'
            Log 'profile updated'
        } catch {
            Log "gh skipped: $_"
        }
    }

    $memes = Join-Path $SG 'memes'
    if (Test-Path (Join-Path $memes '.git')) {
        Push-Location $memes
        try {
            if (git status --porcelain README.md 2>$null) {
                git add README.md
                git commit -m 'Remove location metadata from README' 2>$null
            }
            git push origin main 2>$null
            Log 'memes push attempted'
        } finally { Pop-Location }
    }

    try {
        $remote = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ZacharyGeurts/memes/main/README.md' -UseBasicParsing
        if ($remote.Content -match 'gladstone|michigan') {
            Log 'WARNING: Michigan still on GitHub memes README'
        } else {
            Log 'GitHub memes README clean'
        }
    } catch { Log 'could not verify remote README' }
}

# ── Secure clipboard ───────────────────────────────────────────────────────
function Invoke-MichiganClipboard {
    $sclip = Join-Path $SG 'secure_clipboard.ps1'
    if (-not (Test-Path $sclip)) { throw "missing $sclip" }
    . $sclip
    if ($Init -or -not (Test-Path $script:SClipPassFile)) {
        Initialize-SecureClipboard
    } else {
        Disable-WindowsClipboardLeak
        Log 'sclip already initialized'
    }

    $mark = '# >>> michigan v4 secure-clipboard'
    $profile = $PROFILE.CurrentUserAllHosts
    $dir = Split-Path $profile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (-not (Test-Path $profile) -or -not (Select-String -Path $profile -Pattern $mark -Quiet)) {
        @"

# >>> michigan v4 secure-clipboard
. '$sclip'
Set-Alias -Name scopy  -Value Copy-SecureClipboard  -Scope Global -ErrorAction SilentlyContinue
Set-Alias -Name spaste -Value Paste-SecureClipboard -Scope Global -ErrorAction SilentlyContinue
Set-Alias -Name sclear -Value Clear-SecureClipboard -Scope Global -ErrorAction SilentlyContinue
# <<< michigan v4 secure-clipboard
"@ | Add-Content -Path $profile
        Log "profile hooks → $profile"
    }
    Get-SecureClipboardStatus | Format-List
}

# ── Status ─────────────────────────────────────────────────────────────────
function Invoke-MichiganStatus {
    Log '--- firewall ---'
    Get-NetFirewallProfile | Select-Object Name, DefaultInboundAction, Enabled | Format-Table
    Log '--- SMB ---'
    Get-Service LanmanServer -EA SilentlyContinue | Select-Object Name, Status, StartType
    Log '--- clipboard ---'
    $sclip = Join-Path $SG 'secure_clipboard.ps1'
    if (Test-Path $sclip) {
        . $sclip
        Get-SecureClipboardStatus | Format-List
    }
}

# ── Main ───────────────────────────────────────────────────────────────────
switch ($Action) {
    'All' {
        Invoke-MichiganNet
        Invoke-MichiganScrub
        Invoke-MichiganClipboard
        Log 'v4 complete — reload PowerShell profile for scopy/spaste/sclear'
    }
    'Net'        { Invoke-MichiganNet }
    'Samba'      { Invoke-MichiganSamba }
    'Scrub'      { Invoke-MichiganScrub }
    'Clipboard'  { Invoke-MichiganClipboard }
    'Status'     { Invoke-MichiganStatus }
    'Help'       { Show-Help }
    default      { Show-Help }
}