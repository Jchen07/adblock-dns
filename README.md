# adblock-dns

**Browse on your phone without being buried in ads.** iPhone and Android.

Chrome on phones (iPhone and Android) doesn't allow ad-blocking extensions. This project blocks ads one step earlier, using your own computer.

## Why use it
- **Fewer ads and pop-ups** on websites
- **Fewer redirects** to shops and apps you never asked for
- **Works in Chrome and many apps**, nothing to install on the phone
- **Less tracking** and protection against known dangerous sites
- **Free**, and you control it

> It won't remove everything: YouTube and social media ads still show, and some empty spaces may remain. For now it only works at home.

## Where it works
| Where | Blocks ads? |
|---|---|
| Chrome, Safari, Firefox, Edge | Yes |
| Browsers with their own VPN or DNS turned on | No, they skip the filter |
| Games using ad networks | Often (banners and videos between matches) |
| In-game store offers | No, they come from the game itself |
| YouTube, Instagram, TikTok | Generally no |

**Gamers:** "watch an ad for a reward" may stop working, so you would not get the reward. Switch DNS to **Automatic** for a moment, or unblock the address in **Query log**.

## How it works
A computer at home checks every address your phone asks for. If it belongs to an ad network, it gets blocked. It uses [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome).

**Any computer works:** a Mac, a Windows PC, a Linux laptop, or an old laptop or Raspberry Pi left plugged in. It uses very little power and memory. It only has to be on the same Wi-Fi and awake while you browse.

## Setup
You need that computer with Docker, and a phone (iPhone or Android) on the same Wi-Fi.

### 1. Install Docker
| Computer | What to install |
|---|---|
| Mac | [Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/) |
| Windows 10/11 | [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/) (uses WSL 2; the installer sets it up) |
| Linux, Raspberry Pi | Docker Engine: `curl -fsSL https://get.docker.com -o get-docker.sh`, read it, then `sudo sh get-docker.sh` |

Download this repo (Code > Download ZIP, or `git clone`) and open a terminal in its folder.

### 2. Start it
The shortcuts find the computer's address, write it in `.env` and start the blocker.

**Mac or Linux** (zsh or bash):
```sh
echo "source \"$PWD/shell/adblock.sh\"" >> ~/.zshrc   # bash: ~/.bashrc
source ~/.zshrc
adblock-on
```

**Windows** (PowerShell):
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
if (!(Test-Path $PROFILE)) { New-Item -ItemType File -Force $PROFILE }
Add-Content $PROFILE ". `"$PWD\shell\adblock.ps1`""
. $PROFILE
adblock-on
```
Then allow DNS through the Windows firewall (PowerShell as administrator, once), and make sure your Wi-Fi is set to **Private network**:
```powershell
New-NetFirewallRule -DisplayName "adblock-dns" -Direction Inbound -Protocol UDP -LocalPort 53 -Profile Private -Action Allow
New-NetFirewallRule -DisplayName "adblock-dns TCP" -Direction Inbound -Protocol TCP -LocalPort 53 -Profile Private -Action Allow
```

`adblock-on` prints the address to use on the phone (for example `192.168.1.10`).

<details><summary>Without the shortcuts</summary>

Find the computer's address: Mac `ipconfig getifaddr en0`, Linux `hostname -I`, Windows `ipconfig` (IPv4 Address). Then:
```sh
cp .env.example .env     # write that address in LAN_IP
docker compose up -d
```
</details>

### 3. Set it up
Run:
```sh
adblock-setup
```
It asks for a username and a password for the blocker's panel (you choose them), then applies the recommended settings:
- upstream DNS **Quad9** (`https://dns.quad9.net/dns-query`)
- blocklist **HaGeZi's Pro Blocklist**
- extra rules from [`rules/extra-rules.txt`](rules/extra-rules.txt)
- query logs kept for **24 hours**

The password is only sent to the blocker on this computer and is never saved in a file. If the blocker is already set up, `adblock-setup` changes nothing. To re-apply the recommended settings later: `adblock-setup --reapply` (Windows: `adblock-setup -Reapply`); your own rules and lists are kept.

<details><summary>Do it by hand instead</summary>

Open http://127.0.0.1:3000 on that computer:
- Change the web interface port from 80 to **3000**
- Keep the DNS port at **53**
- Create a user and a strong password
- On the "configure your devices" page, just click Next

Then, in the panel:
- **Settings > DNS settings:** replace the upstream server with `https://dns.quad9.net/dns-query`
- **Settings > General:** keep query logs for **24 hours**
- **Filters > DNS blocklists:** Add blocklist > Choose from the list > **HaGeZi's Pro Blocklist**
- Optional: **Filters > Custom filtering rules:** paste the rules from [`rules/extra-rules.txt`](rules/extra-rules.txt)
</details>

### 4. Connect the phone
**iPhone**
1. **Settings > Wi-Fi**, tap **(i)** next to your network
2. **Configure DNS > Manual**
3. Delete all servers, add the address from step 2, **Save**
4. Turn off "Limit IP Address Tracking", iCloud Private Relay and any VPN
5. Turn airplane mode on and off

**Android** (menu names vary by brand: Samsung, Xiaomi, Pixel...)
1. **Settings > Network & internet > Private DNS: Off** (otherwise it skips the filter)
2. **Wi-Fi**, tap your network > edit (pencil or gear) > **Advanced options**
3. **IP settings: Static**. Keep the IP address, gateway and prefix it shows (write them down first if they appear empty: see them in the network details)
4. **DNS 1:** the address from step 2. Leave **DNS 2 empty**, or ads get through
5. **Save**, then turn Wi-Fi off and on

Done. Open your usual websites.

**Whole home instead (optional):** in your router's settings (DHCP / LAN), set the DNS server to the computer's address. Every device on the Wi-Fi is filtered with no phone setup. Only do this if that computer is always on (a Raspberry Pi is ideal): when it is off, nobody at home has internet. Reserve a fixed address for the computer in the router first.

### 5. Keep it awake
If the computer sleeps, the phone loses internet on that Wi-Fi.
| Computer | Setting |
|---|---|
| Mac | System Settings > Battery (or Energy) > prevent automatic sleeping when the display is off |
| Windows | Settings > System > Power > Sleep: **Never** when plugged in |
| Linux laptop | Power settings: no suspend on AC; to keep it running with the lid closed set `HandleLidSwitch=ignore` in `/etc/systemd/logind.conf` |

## Shortcuts
| Command | What it does |
|---|---|
| `adblock-on` | Starts Docker if needed, updates the address in `.env`, starts the blocker, shows the address |
| `adblock-off` | Stops the blocker. Your settings are kept |
| `adblock-status` | Shows if it is running (no output means off) |
| `adblock-ip` | Shows the computer's address |
| `adblock-setup` | First-time setup with the recommended settings (step 3). Changes nothing if already set up |

Order matters: **when turning off**, first set the phone's DNS back to automatic (iPhone: **Automatic**; Android: IP settings **DHCP**), then run `adblock-off`. **When turning on**, run `adblock-on`, then set the phone's DNS again.

If you move the repo folder, update the line in your shell profile.

## Away from home
You don't need to change anything on the phone: the DNS setting is saved only for your home Wi-Fi.

| Where you are | What happens |
|---|---|
| Home, computer awake and blocker running | Ads filtered |
| Mobile data or another Wi-Fi | Normal internet, no filter |
| Home, computer asleep or off | **No internet** on that Wi-Fi: set DNS to Automatic or wake the computer |

## Problems?
| Problem | Solution |
|---|---|
| Phone has no internet | Check the computer is awake and `adblock-status` shows it running. To undo: iPhone **Configure DNS > Automatic**, Android **IP settings > DHCP** |
| Computer's address changed | Run `adblock-on` again and put the new address on the phone. Tip: reserve a fixed address for it in your router (DHCP reservation) |
| Windows: the phone can't reach it | Wi-Fi must be a **Private network** and the firewall rules from step 2 must exist |
| Linux: "address already in use" on port 53 | Another DNS service uses that address (e.g. dnsmasq). Stop it, or check with `sudo ss -lunp 'sport = :53'` |
| A website stopped working | In the panel, open **Query log** and unblock the address |
| Some ads still appear | In the panel, find the address in **Query log** and block it |
| Android: nothing is filtered | **Private DNS** must be **Off**, and **DNS 2** must be empty |

To stop it, set the phone's DNS back to automatic, then run `adblock-off` (or `docker compose down`).

## Use it anywhere
To run it on a small paid server instead of a computer at home, see [docs/vps.md](docs/vps.md).

## Stay safe
- Never expose port 53 or the admin panel to the internet. The local setup is for your home network only; for a server follow [docs/vps.md](docs/vps.md).
- Never share the `data/` folder: it contains your browsing history.
- Keep AdGuard Home updated.
