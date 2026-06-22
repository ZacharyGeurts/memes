# amouranth.ps1 — Amouranth Shield (forwards to ammo.ps1, no -Action required)
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Command = @()
)
$Dir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
& "$Dir\ammo.ps1" @Command