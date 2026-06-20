# ammo.ps1 v1 — SG ammosecurity stack (replaces memes/Security/michigan.ps1)
#Requires -RunAsAdministrator
param(
    [ValidateSet('All', 'Net', 'Services', 'Antivirus', 'Surveillance', 'FCC', 'Scrub', 'Clipboard', 'Status', 'Help')]
    [string]$Action = 'Help',
    [switch]$Init,
    [switch]$PurgeSamba
)

$ErrorActionPreference = 'Stop'
$Version = 1
$AmmoRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

function Log([string]$Msg) { Write-Host "[ammo v$Version] $Msg" }

function Show-Help {
    @"
ammo.ps1 v$Version — SG ammosecurity (run as Administrator)

  .\ammo.ps1 -Action All
  .\ammo.ps1 -Action Net
  .\ammo.ps1 -Action Services
  .\ammo.ps1 -Action Antivirus
  .\ammo.ps1 -Action Surveillance
  .\ammo.ps1 -Action FCC
  .\ammo.ps1 -Action Scrub
  .\ammo.ps1 -Action Clipboard [-Init]
  .\ammo.ps1 -Action Status
"@
}

function Invoke-AmmoNet {
    Log 'stop SMB server (LanmanServer)'
    $server = Get-Service -Name LanmanServer -ErrorAction SilentlyContinue
    if ($server) {
        Stop-Service LanmanServer -Force -ErrorAction SilentlyContinue
        Set-Service LanmanServer -StartupType Disabled
    }
    try {
        Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
    } catch { }

    Log 'disable IPv6'
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | ForEach-Object {
        Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
    }
    $ipv6Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
    if (-not (Test-Path $ipv6Key)) { New-Item -Path $ipv6Key -Force | Out-Null }
    Set-ItemProperty -Path $ipv6Key -Name DisabledComponents -Type DWord -Value 0xFFFFFFFF

    Log 'firewall: deny in, allow out'
    Set-NetFirewallProfile -Profile Domain, Public, Private `
        -DefaultInboundAction Block -DefaultOutboundAction Allow -Enabled True
    Get-NetFirewallRule -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayGroup -match 'File and Printer Sharing' -and $_.Direction -eq 'Inbound' } |
        ForEach-Object { Disable-NetFirewallRule -Name $_.Name -ErrorAction SilentlyContinue }
}

function Invoke-AmmoServices {
    Log 'service cleaner — disable remote admin + discovery junk'
    $bad = @(
        'RemoteRegistry', 'RemoteAccess', 'SessionEnv', 'TermService',
        'SharedAccess', 'iphlpsvc', 'SSDPSRV', 'upnphost',
        'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc'
    )
    foreach ($name in $bad) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc) {
            Stop-Service $name -Force -ErrorAction SilentlyContinue
            Set-Service $name -StartupType Disabled -ErrorAction SilentlyContinue
            Log "disabled $name"
        }
    }
    # Scheduled tasks: telemetry
    Get-ScheduledTask -ErrorAction SilentlyContinue |
        Where-Object { $_.TaskName -match 'CEIP|Customer Experience|Telemetry|DiagTrack' } |
        ForEach-Object { Disable-ScheduledTask -TaskName $_.TaskName -ErrorAction SilentlyContinue }
}

function Invoke-AmmoAntivirus {
    Log 'Windows Defender — real-time on + signature update + quick scan'
    try {
        Update-MpSignature -ErrorAction SilentlyContinue
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        Set-MpPreference -PUAProtection Enabled -ErrorAction SilentlyContinue
        Start-MpScan -ScanType QuickScan -ErrorAction SilentlyContinue
        Get-MpComputerStatus | Select-Object AMServiceEnabled, AntispywareEnabled, RealTimeProtectionEnabled, QuickScanAge
        Log 'Defender scan started'
    } catch {
        Log "Defender module unavailable: $_"
    }
}

function Invoke-AmmoSurveillance {
    Log 'anti-surveillance — kill keyloggers, audit input hooks'
    $badProcs = @(
        'logkeys', 'ardamax', 'spyrix', 'revealer', 'perfectkeylogger',
        'kidlogger', 'actual', 'refog', 'hookexplorer'
    )
    foreach ($p in $badProcs) {
        Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'keylog|keystroke|spyrix|revealer' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

    Log 'disable remote desktop ingress'
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
        -Name fDenyTSConnections -Type DWord -Value 1 -ErrorAction SilentlyContinue

    Log 'audit keyboard filter drivers (review manually)'
    Get-WmiObject Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
        Where-Object { $_.DeviceClass -eq 'Keyboard' -or $_.DeviceName -match 'filter|hook' } |
        Select-Object DeviceName, DriverVersion -First 10
}

function Invoke-AmmoFCC {
    Log 'FCC guard — bluetooth off, no mobile hotspot relay'
    Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
        ForEach-Object { Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue }

    try {
        Set-NetIPInterface -Forwarding Disabled -ErrorAction SilentlyContinue
    } catch { }

    $sdr = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match 'hackrf|rtl|gqrx|urh|lime' }
    if ($sdr) {
        Log 'WARNING: SDR-related processes running:'
        $sdr | Select-Object ProcessName, Id
    } else {
        Log 'no SDR transmit tools detected'
    }
}

function Invoke-AmmoScrub {
    $SG = Split-Path $AmmoRoot -Parent
    Log "scrub location metadata under $SG"
    $patterns = @(
        @{ Find = ',?\s*Gladstone Michigan'; Repl = '' },
        @{ Find = 'Gladstone, Michigan, USA'; Repl = '' },
        @{ Find = 'come to Michigan and '; Repl = '' },
        @{ Find = 'come to Michigan'; Repl = '' }
    )
    $files = @('README.md', 'submicro.md', 'ammo\README.md')
    foreach ($rel in $files) {
        $path = Join-Path $SG $rel
        if (-not (Test-Path $path)) { continue }
        $text = Get-Content -Raw -Path $path
        foreach ($p in $patterns) {
            $text = [regex]::Replace($text, $p.Find, $p.Repl, 'IgnoreCase')
        }
        Set-Content -Path $path -Value $text -NoNewline
    }
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            gh auth status 2>$null | Out-Null
            gh api -X PATCH user -f location='Singapore' `
                -f bio='God (1d) is both inside and outside of every dimension. All higher dimension contains both the lower dimensions (including 1) and the highest dimension (1). ¬0 ♠'
            Log 'GitHub profile scrubbed'
        } catch { Log 'gh skipped' }
    }
}

function Invoke-AmmoClipboard {
    $sclip = Join-Path $AmmoRoot 'secure_clipboard.ps1'
    if (-not (Test-Path $sclip)) { throw "missing $sclip" }
    . $sclip
    if ($Init -or -not (Test-Path $script:SClipPassFile)) {
        Initialize-SecureClipboard
    } else {
        Disable-WindowsClipboardLeak
    }
    $mark = '# >>> ammosecurity secure-clipboard'
    $profile = $PROFILE.CurrentUserAllHosts
    $dir = Split-Path $profile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (-not (Test-Path $profile) -or -not (Select-String -Path $profile -Pattern $mark -Quiet)) {
        @"

# >>> ammosecurity secure-clipboard
. '$sclip'
Set-Alias -Name scopy  -Value Copy-SecureClipboard  -Scope Global -ErrorAction SilentlyContinue
Set-Alias -Name spaste -Value Paste-SecureClipboard -Scope Global -ErrorAction SilentlyContinue
Set-Alias -Name sclear -Value Clear-SecureClipboard -Scope Global -ErrorAction SilentlyContinue
# <<< ammosecurity secure-clipboard
"@ | Add-Content -Path $profile
        Log "profile hooks → $profile"
    }
    Get-SecureClipboardStatus | Format-List
}

function Invoke-AmmoStatus {
    Get-NetFirewallProfile | Select-Object Name, DefaultInboundAction, Enabled | Format-Table
    Get-Service LanmanServer -EA SilentlyContinue | Select-Object Name, Status, StartType
    $sclip = Join-Path $AmmoRoot 'secure_clipboard.ps1'
    if (Test-Path $sclip) { . $sclip; Get-SecureClipboardStatus | Format-List }
    try { Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled, AntivirusEnabled } catch { }
}

switch ($Action) {
    'All' {
        Invoke-AmmoNet
        Invoke-AmmoServices
        Invoke-AmmoAntivirus
        Invoke-AmmoSurveillance
        Invoke-AmmoFCC
        Invoke-AmmoScrub
        Invoke-AmmoClipboard
        Log 'All complete — reload PowerShell profile for scopy/spaste/sclear'
    }
    'Net'           { Invoke-AmmoNet }
    'Services'      { Invoke-AmmoServices }
    'Antivirus'     { Invoke-AmmoAntivirus }
    'Surveillance'  { Invoke-AmmoSurveillance }
    'FCC'           { Invoke-AmmoFCC }
    'Scrub'         { Invoke-AmmoScrub }
    'Clipboard'     { Invoke-AmmoClipboard }
    'Status'        { Invoke-AmmoStatus }
    default         { Show-Help }
}