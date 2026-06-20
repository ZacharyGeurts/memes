# michigan.ps1 — backward-compat wrapper → ammo.ps1 (ammosecurity v1)
param(
    [string]$Action = 'Help',
    [switch]$Init,
    [switch]$PurgeSamba
)
$Dir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$map = @{
    'All' = 'All'; 'Net' = 'Net'; 'Samba' = 'Net'; 'Scrub' = 'Scrub'
    'Clipboard' = 'Clipboard'; 'Status' = 'Status'; 'Help' = 'Help'
    'Services' = 'Services'; 'Antivirus' = 'Antivirus'
    'Surveillance' = 'Surveillance'; 'FCC' = 'FCC'; 'HumanContact' = 'HumanContact'; 'Clasp' = 'Clasp'
}
$mapped = if ($map.ContainsKey($Action)) { $map[$Action] } else { $Action }
& "$Dir\ammo.ps1" -Action $mapped @PSBoundParameters