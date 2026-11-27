# Shortcuts for adblock-dns on Windows (PowerShell + Docker Desktop).
# Load from your profile:  Add-Content $PROFILE ". `"$PWD\shell\adblock.ps1`""

$AdblockDir = Split-Path -Parent $PSScriptRoot

# This computer's address on the home network
function adblock-ip {
    $ip = (Get-NetIPConfiguration |
        Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
        Select-Object -First 1).IPv4Address.IPAddress
    if (-not $ip) { Write-Error 'Could not find the network address. Is Wi-Fi or Ethernet connected?'; return }
    $ip
}

function Start-AdblockDocker {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { return $true }
    Write-Host 'Opening Docker Desktop...'
    Start-Process "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 2
        docker info *> $null
        if ($LASTEXITCODE -eq 0) { return $true }
    }
    Write-Error 'Docker did not start'
    $false
}

function adblock-on {
    $ip = adblock-ip
    if (-not $ip) { return }
    if (-not (Start-AdblockDocker)) { return }
    # Keep .env in sync with the current address, so a new IP just works
    Set-Content -Path (Join-Path $AdblockDir '.env') -Value "LAN_IP=$ip" -Encoding ascii
    docker compose --project-directory $AdblockDir up -d
    if ($LASTEXITCODE -ne 0) { return }
    Write-Host "Ad blocker ON. DNS server: $ip"
    Write-Host "Phone: set the Wi-Fi DNS to $ip (README step 4)"
}

function adblock-off {
    Write-Host 'Remember: set the phone DNS back to automatic.'
    docker compose --project-directory $AdblockDir down
    if ($LASTEXITCODE -eq 0) { Write-Host 'Ad blocker OFF' }
}

function adblock-status {
    docker ps --filter name=adguardhome --format '{{.Names}}: {{.Status}}'
}

# ---------------------------------------------------------------------------
# adblock-setup: first-time setup with the recommended settings (README step 3).
# Asks only for a username and password. Never changes an existing setup;
# `adblock-setup -Reapply` logs in and re-applies only the recommended settings.
# The password is sent only to AdGuard Home on this computer, never saved.

$AdblockUrl = if ($env:ADBLOCK_URL) { $env:ADBLOCK_URL } else { 'http://127.0.0.1:3000' }
$AdblockUpstream = 'https://dns.quad9.net/dns-query'
$AdblockListName = "HaGeZi's Pro Blocklist"
$AdblockListUrl = 'https://adguardteam.github.io/HostlistsRegistry/assets/filter_48.txt'

# Calls the panel API. Returns Code (0 = no answer), Text and Json.
function Invoke-AdblockApi($Method, $Path, $Session, $Body) {
    $p = @{
        Method = $Method; Uri = "$AdblockUrl/control$Path"; WebSession = $Session
        UseBasicParsing = $true; MaximumRedirection = 0; ErrorAction = 'Stop'
    }
    if ($null -ne $Body) {
        $p.ContentType = 'application/json'   # exactly this: AdGuard Home rejects a charset suffix
        $p.Body = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Body -Depth 6 -Compress))
    }
    try {
        $r = Invoke-WebRequest @p
        $code = [int]$r.StatusCode; $text = [string]$r.Content
    } catch {
        $resp = $_.Exception.Response
        $code = if ($resp) { [int]$resp.StatusCode } else { 0 }
        $text = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $_.Exception.Message }
    }
    $json = $null
    if ($code -eq 200 -and $text) { try { $json = $text | ConvertFrom-Json } catch { } }
    [pscustomobject]@{ Code = $code; Text = $text; Json = $json }
}

function ConvertFrom-AdblockSecure($Secure) {
    [Net.NetworkCredential]::new('', $Secure).Password
}

function adblock-setup {
    param([switch]$Reapply)
    $ProgressPreference = 'SilentlyContinue'   # no download bars (also much faster on Windows PowerShell 5.1)
    $s = New-Object Microsoft.PowerShell.Commands.WebRequestSession

    $r = Invoke-AdblockApi GET /install/get_addresses $s
    if ($r.Code -eq 0) { Write-Host 'The blocker is not running. Run adblock-on first.'; return }
    $fresh = $r.Code -eq 200
    if (-not $fresh -and -not $Reapply) {
        Write-Host 'Already set up: nothing changed.'
        Write-Host 'To re-apply the recommended settings (asks for your login): adblock-setup -Reapply'
        return
    }

    # Credentials, typed by the user only
    if ($fresh) {
        Write-Host "Create the login for the blocker's panel ($AdblockUrl)."
        $user = Read-Host 'Username'
    } else {
        $user = Read-Host 'Panel username'
    }
    if (-not $user) { Write-Host "The username can't be empty."; return }
    while ($true) {
        $pass = ConvertFrom-AdblockSecure (Read-Host 'Password' -AsSecureString)
        if (-not $fresh) { break }
        if ($pass.Length -lt 8) { Write-Host 'At least 8 characters, try again.'; continue }
        if ($pass.Length -gt 72) { Write-Host 'At most 72 characters, try again.'; continue }
        $pass2 = ConvertFrom-AdblockSecure (Read-Host 'Same password again' -AsSecureString)
        if ($pass -ceq $pass2) { break }
        Write-Host "They don't match, try again."
    }
    $pass2 = $null

    if ($fresh) {
        Write-Host 'Setting up...'
        $r = Invoke-AdblockApi POST /install/configure $s @{
            web = @{ ip = '0.0.0.0'; port = 3000 }; dns = @{ ip = '0.0.0.0'; port = 53 }
            username = $user; password = $pass
        }
        switch ($r.Code) {
            200 { }
            422 { Write-Host "AdGuard Home says the password is too weak: $($r.Text). Run adblock-setup again with a stronger one."; return }
            400 { Write-Host "Could not use port 53 or 3000 ($($r.Text)). Close the program using them, then run adblock-off, adblock-on and adblock-setup."; return }
            default { Write-Host "Setup failed (HTTP $($r.Code)): $($r.Text)"; return }
        }
        # The panel restarts after the first setup
        for ($i = 0; (Invoke-AdblockApi GET /status $s).Code -eq 0; $i++) {
            if ($i -ge 30) { Write-Host 'The panel did not come back. Check with adblock-status.'; return }
            Start-Sleep -Seconds 1
        }
    }

    $r = Invoke-AdblockApi POST /login $s @{ name = $user; password = $pass }
    $pass = $null
    switch ($r.Code) {
        200 { }
        { $_ -in 400, 401, 403 } { Write-Host 'Wrong username or password.'; return }
        429 { Write-Host 'Too many login attempts. Wait a few minutes and try again.'; return }
        default { Write-Host "Login failed (HTTP $($r.Code))."; return }
    }

    # Upstream DNS
    $r = Invoke-AdblockApi POST /dns_config $s @{ upstream_dns = @($AdblockUpstream) }
    if ($r.Code -ne 200) { Write-Host "Could not set the upstream DNS (HTTP $($r.Code)): $($r.Text)"; return }
    Write-Host '  OK Upstream DNS: Quad9'

    # Blocklist (only if it isn't there yet)
    $f = Invoke-AdblockApi GET /filtering/status $s
    if ($f.Code -ne 200) { Write-Host "Could not read the blocklists (HTTP $($f.Code))."; return }
    if (@($f.Json.filters | Where-Object { $_.url -eq $AdblockListUrl }).Count -gt 0) {
        Write-Host "  OK $AdblockListName (already there)"
    } else {
        $r = Invoke-AdblockApi POST /filtering/add_url $s @{ name = $AdblockListName; url = $AdblockListUrl; whitelist = $false }
        if ($r.Code -ne 200) { Write-Host "Could not download $AdblockListName. Check the internet connection, then run: adblock-setup -Reapply"; return }
        Write-Host "  OK $AdblockListName"
    }

    # Extra rules from the repo, added to the user's own rules (no duplicates)
    $rules = New-Object System.Collections.Generic.List[string]
    if ($f.Json.user_rules) { foreach ($x in $f.Json.user_rules) { $rules.Add([string]$x) } }
    $added = 0
    foreach ($line in Get-Content (Join-Path $AdblockDir 'rules\extra-rules.txt')) {
        $line = $line.TrimEnd("`r")
        if (-not $line -or $line.StartsWith('#') -or $line.StartsWith('!')) { continue }
        if ($rules.Contains($line)) { continue }
        $rules.Add($line); $added++
    }
    if ($added -gt 0) {
        $r = Invoke-AdblockApi POST /filtering/set_rules $s @{ rules = $rules.ToArray() }
        if ($r.Code -ne 200) { Write-Host "Could not add the extra rules (HTTP $($r.Code)): $($r.Text)"; return }
    }
    Write-Host "  OK Extra rules: $added added"

    # Query log: on, 24 hours
    $q = Invoke-AdblockApi GET /querylog/config $s
    if ($q.Code -ne 200) { Write-Host "Could not read the query log settings (HTTP $($q.Code))."; return }
    $q.Json.enabled = $true
    $q.Json.interval = 86400000
    $r = Invoke-AdblockApi PUT /querylog/config/update $s $q.Json
    if ($r.Code -ne 200) { Write-Host "Could not set the query log (HTTP $($r.Code))."; return }
    Write-Host '  OK Query log: 24 hours'

    $ip = adblock-ip 2>$null
    Write-Host "Done. Panel: $AdblockUrl (user: $user)"
    if ($ip) { Write-Host "Phone: set the Wi-Fi DNS to $ip (README step 4)" }
}
