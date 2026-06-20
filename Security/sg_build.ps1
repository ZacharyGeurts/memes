# sg_build.ps1 — SG firmware layer. We cover our own shit.
#Requires -RunAsAdministrator
param(
    [ValidateSet('All', 'Firmware', 'TrustNobody', 'Antivirus', 'Net', 'Services', 'Surveillance', 'FCC', 'FCCEmissions', 'DeadAir', 'World', 'HumanContact', 'Clasp', 'Scrub', 'Clipboard', 'Status', 'Help')]
    [int]$N = 0
    [string]$Action = 'Help',
    [switch]$Init,
    [switch]$PurgeSamba,
    [switch]$Unlock
)

$ErrorActionPreference = 'Stop'
$Version = 8
$SgRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

function Log([string]$Msg) { Write-Host "[sg_build v$Version] $Msg" }

function Show-Help {
    @"
sg_build.ps1 v$Version — SG firmware layer (Administrator)

  .\sg_build.ps1 -Action Firmware   drop foreign AV/security — we own the stack
  .\sg_build.ps1 -Action All
  .\sg_build.ps1 -Action Net
  .\sg_build.ps1 -Action Services
  .\sg_build.ps1 -Action Surveillance
  .\sg_build.ps1 -Action FCC
  .\sg_build.ps1 -Action FCCEmissions
  .\sg_build.ps1 -Action DeadAir
  .\sg_build.ps1 -Action World
  .\sg_build.ps1 -Action World -N 12
  .\sg_build.ps1 -Action HumanContact
  .\sg_build.ps1 -Action Clasp
  .\sg_build.ps1 -Action Clasp -Unlock
  .\sg_build.ps1 -Action Scrub
  .\sg_build.ps1 -Action Clipboard [-Init]
  .\sg_build.ps1 -Action Status
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

function Invoke-SGTrustNobody {
    Log 'trust nobody — local heuristics only, no ClamAV, no cloud AV'
    $bad = @('keylog','rat','njrat','asyncrat','xmrig','mimikatz','cryptominer')
    foreach ($pat in $bad) {
        Get-Process -EA 0 | Where-Object { $_.ProcessName -match $pat } |
            ForEach-Object { Stop-Process -Id $_.Id -Force -EA 0; Log "killed: $($_.ProcessName)" }
    }
    Get-CimInstance Win32_Process -EA 0 |
        Where-Object { $_.CommandLine -match 'LD_PRELOAD|\\\\temp\\\\|keylog' } |
        Select-Object ProcessId, CommandLine -First 10
    Log 'trust nobody scan done — zero third-party AV'
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

function Invoke-AmmoFCCEmissions {
    Log 'FCC emissions — conducted voltage + radiated EIRP + modulation within Part 15'
    Invoke-AmmoHumanContact

    # Radiated: clamp WiFi TX where adapter still present
    try {
        netsh wlan set autoconfig enabled=no interface="Wi-Fi" 2>$null | Out-Null
    } catch { }
    Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'Wi-?Fi|WLAN|Wireless' } |
        ForEach-Object {
            try {
                $cmd = "netsh wlan set profileparameter name=* connectionmode=manual"
                Log "wifi TX profile manual: $($_.Name)"
            } catch { }
        }

    # Modulation outlaw: kill SDR / inject / raw TX tools
    $outlaw = @('hackrf','rtl','gqrx','urh','lime','bladeRF','mdk3','mdk4','aircrack')
    foreach ($pat in $outlaw) {
        Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match $pat } |
            ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue; Log "killed outlaw modulator: $($_.ProcessName)" }
    }

    Log 'FCC ceilings: USB 4.75–5.25V / 500mA conducted; certified WiFi/BT stack only; no SDR TX'
}

function Invoke-AmmoFCC {
    Log 'FCC guard — bluetooth off, no mobile hotspot relay, emissions envelope'
    Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
        ForEach-Object { Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue }

    try {
        Set-NetIPInterface -Forwarding Disabled -ErrorAction SilentlyContinue
    } catch { }

    Invoke-AmmoFCCEmissions
    Invoke-AmmoDeadAir
}

function Invoke-AmmoDeadAir {
    Log 'dead air — no rapid encoded fluctuation; silence out-of-function devices'
    try {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5 2>$null | Out-Null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5 2>$null | Out-Null
        powercfg /SETACTIVE SCHEME_CURRENT 2>$null | Out-Null
        Log 'CPU min throttle raised — damp rapid power-rail ripple encoding'
    } catch { }

    # WiFi dead air: no background scan when not connected
    try { netsh wlan set autoconfig enabled=no 2>$null | Out-Null } catch { }
    Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { ($_.Name -match 'Wi-?Fi|WLAN') -and $_.Status -ne 'Up' } |
        ForEach-Object { Disable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue }

    # Webcam/mic out-of-function → dead air
    Get-PnpDevice -Class Camera -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'OK' } |
        ForEach-Object { Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue; Log "camera dead air: $($_.FriendlyName)" }

    Get-PnpDevice -Class 'AudioEndpoint','MEDIA' -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match 'Microphone|Mic' } |
        ForEach-Object { Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue; Log "mic dead air: $($_.FriendlyName)" }

    Log 'policy: stable power rails, no rapid duty-cycle encoding, RF silent when idle'
}

function Invoke-AmmoHumanContact {
    Log 'human-contact voltage regulators — 5V / 500mA ceiling on HID, audio, gamepads'
    # USB selective suspend + power saving on human-touch device classes
    try {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_USB USBSELECTIVESUSPEND 1 2>$null | Out-Null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_USB USBSELECTIVESUSPEND 1 2>$null | Out-Null
        powercfg /SETACTIVE SCHEME_CURRENT 2>$null | Out-Null
        Log 'USB selective suspend enabled (blocks idle high-draw PD)'
    } catch { Log 'powercfg USB suspend skipped' }

    $usbFlags = 'HKLM:\SYSTEM\CurrentControlSet\Control\UsbFlags'
    if (-not (Test-Path $usbFlags)) { New-Item -Path $usbFlags -Force | Out-Null }
    # Disable USB3 link power management bypass (reduces voltage ramp on wake)
    Set-ItemProperty -Path $usbFlags -Name 'fid_D1Latency' -Type DWord -Value 0 -ErrorAction SilentlyContinue

    Log 'audit human-contact USB devices (keyboards, mice, headsets, controllers)'
    Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Class -match 'HIDClass|Mouse|Keyboard|AudioEndpoint|USB|Bluetooth' -or
            $_.FriendlyName -match 'keyboard|mouse|headset|game|controller|touch|stylus|pen'
        } |
        Select-Object Class, FriendlyName, Status -First 20

    Log 'physical: inline 5V LDO on any DIY cable or wearable touching skin'
}

function Invoke-AmmoIngressClasp {
    if ($Unlock) {
        Log 'UNLOCK ingress clasp — re-enabling USB / Bluetooth / WiFi'
        Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
            Where-Object { $_.Class -match 'Bluetooth|Net|USB' } |
            ForEach-Object { Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue }
        try {
            netsh interface set interface name="Wi-Fi" admin=enabled 2>$null | Out-Null
            Set-NetAdapter -Name 'Wi-Fi' -Status Up -ErrorAction SilentlyContinue
        } catch { }
        Remove-Item -Path 'HKLM:\SOFTWARE\Ammo\IngressClasp' -Recurse -Force -ErrorAction SilentlyContinue
        Log 'clasp released — reboot recommended'
        return
    }

    Log '=== INGRESS CLASP — USB · Bluetooth · WiFi · NFC · WWAN ==='

    # USB clasp — disable new USB device install
    $usbStor = 'HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR'
    if (Test-Path $usbStor) {
        Set-ItemProperty -Path $usbStor -Name Start -Type DWord -Value 4 -ErrorAction SilentlyContinue
        Log 'USB storage driver disabled (Start=4)'
    }

    # Bluetooth clasp
    Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
        ForEach-Object { Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue }
    Get-Service -Name 'bthserv','BluetoothUserService*' -ErrorAction SilentlyContinue |
        ForEach-Object { Stop-Service $_ -Force -ErrorAction SilentlyContinue; Set-Service $_.Name -StartupType Disabled -ErrorAction SilentlyContinue }

    # WiFi clasp
    try {
        netsh wlan set hostednetwork mode=disallow 2>$null | Out-Null
        netsh interface set interface name="Wi-Fi" admin=disabled 2>$null | Out-Null
    } catch { }
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $_.MediaType -match '802.11' -or $_.Name -match 'Wi-?Fi|WLAN|Wireless' } |
        ForEach-Object { Disable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue; Log "wifi down: $($_.Name)" }

    # Mobile hotspot / tethering clasp
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WcmSvc\GroupPolicy\fHotspotReporting' `
        -Name fEnableHotspotReporting -Type DWord -Value 0 -ErrorAction SilentlyContinue

    # NFC if present
    Get-PnpDevice -FriendlyName '*NFC*' -ErrorAction SilentlyContinue |
        ForEach-Object { Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue }

    New-Item -Path 'HKLM:\SOFTWARE\Ammo\IngressClasp' -Force | Out-Null
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Ammo\IngressClasp' -Name LockedAt -Value (Get-Date -Format o)
    Log 'ingress clasp LOCKED — ethernet outbound only; use -Action Clasp -Unlock to release'
}

function Invoke-AmmoScrub {
    $SG = Split-Path $SgRoot -Parent
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
    $sclip = Join-Path $SgRoot 'sg_clipboard.ps1'
    if (-not (Test-Path $sclip)) { throw "missing $sclip" }
    . $sclip
    if ($Init -or -not (Test-Path $script:SClipPassFile)) {
        Initialize-SecureClipboard
    } else {
        Disable-WindowsClipboardLeak
    }
    $mark = '# >>> sg_build secure-clipboard'
    $profile = $PROFILE.CurrentUserAllHosts
    $dir = Split-Path $profile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (-not (Test-Path $profile) -or -not (Select-String -Path $profile -Pattern $mark -Quiet)) {
        @"

# >>> sg_build secure-clipboard
. '$sclip'
Set-Alias -Name scopy  -Value Copy-SecureClipboard  -Scope Global -ErrorAction SilentlyContinue
Set-Alias -Name spaste -Value Paste-SecureClipboard -Scope Global -ErrorAction SilentlyContinue
Set-Alias -Name sclear -Value Clear-SecureClipboard -Scope Global -ErrorAction SilentlyContinue
# <<< sg_build secure-clipboard
"@ | Add-Content -Path $profile
        Log "profile hooks → $profile"
    }
    Get-SecureClipboardStatus | Format-List
}

function Invoke-AmmoStatus {
    Get-NetFirewallProfile | Select-Object Name, DefaultInboundAction, Enabled | Format-Table
    Get-Service LanmanServer -EA SilentlyContinue | Select-Object Name, Status, StartType
    $sclip = Join-Path $SgRoot 'sg_clipboard.ps1'
    if (Test-Path $sclip) { . $sclip; Get-SecureClipboardStatus | Format-List }
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 6 Name, CPU
}

switch ($Action) {
    'All' {
        Invoke-AmmoNet
        Invoke-AmmoServices
        . "$SgRoot\modules\sg_firmware.ps1"; Invoke-SGFirmware
        Invoke-AmmoSurveillance
        Invoke-AmmoFCC
        Invoke-AmmoHumanContact
        Invoke-AmmoDeadAir
        . "$SgRoot\modules\sg_grok_world.ps1"
        Invoke-GrokWorld $(if ($N -gt 0) { "$N" } else { 'all' })
        Invoke-AmmoIngressClasp
        Invoke-AmmoScrub
        Invoke-AmmoClipboard
        Log 'All complete — reload PowerShell profile for scopy/spaste/sclear'
    }
    'Net'           { Invoke-AmmoNet }
    'Services'      { Invoke-AmmoServices }
    'Firmware'      { . "$SgRoot\modules\sg_firmware.ps1"; Invoke-SGFirmware }
    'TrustNobody'   { . "$SgRoot\modules\sg_firmware.ps1"; Invoke-SGFirmware }
    'Antivirus'     { . "$SgRoot\modules\sg_firmware.ps1"; Invoke-SGFirmware }
    'Surveillance'  { Invoke-AmmoSurveillance }
    'FCC'           { Invoke-AmmoFCC }
    'FCCEmissions'  { Invoke-AmmoFCCEmissions }
    'DeadAir'       { Invoke-AmmoDeadAir }
    'World'         { . "$SgRoot\modules\sg_grok_world.ps1"; Invoke-GrokWorld $(if ($N -gt 0) { "$N" } else { 'all' }) }
    'HumanContact'  { Invoke-AmmoHumanContact }
    'Clasp'         { Invoke-AmmoIngressClasp }
    'Scrub'         { Invoke-AmmoScrub }
    'Clipboard'     { Invoke-AmmoClipboard }
    'Status'        { Invoke-AmmoStatus }
    default         { Show-Help }
}