# BEAD VPN Install Package

This package installs the current BEAD VPN panel on a fresh Ubuntu VPS or updates
the domain on an existing VPS.

## Before Install

1. Create an Ubuntu 22.04 or 24.04 VPS.
2. Point the domain DNS A record to the new VPS IP.
3. Wait until DNS resolves before issuing SSL.

Check DNS:

```bash
dig +short your-domain.com
```

## Fresh VPS Install

Upload this folder to the VPS, then run:

```bash
cd /root/bead-vpn-install
chmod +x *.sh
sudo ./install-bead-vpn-panel.sh
```

Fast install without questions:

```bash
cd /root/bead-vpn-install
chmod +x *.sh
sudo ./quick-install.sh your-domain.com admin your-panel-password
```

## Windows One Step Deploy

From the folder that contains `deploy-bead-vpn.ps1`, run PowerShell:

```powershell
.\deploy-bead-vpn.ps1 -ServerIp 1.2.3.4 -Domain vpn.example.com -PanelUser admin -PanelPass "your-panel-password"
```

If SSH asks for a password, enter the VPS root password.

If using an SSH key:

```powershell
.\deploy-bead-vpn.ps1 -ServerIp 1.2.3.4 -Domain vpn.example.com -PanelUser admin -PanelPass "your-panel-password" -KeyPath "C:\path\to\key"
```

## GitHub Deploy

If this package is uploaded to GitHub, see `GITHUB_DEPLOY.md` in the repository root.

The installer asks for:

- Domain
- Panel username
- Panel password
- Whether to issue SSL with certbot

It installs:

- `index.html` and `sshws.html`
- API service `chaiya-ssh-api` on `127.0.0.1:6789`
- Nginx reverse proxy for `/api/` and `/ssh`
- Dropbear on ports `109` and `143`
- WebSocket SSH bridge through `websockify`
- SSL certificate when selected

## Change Domain On Same VPS

After pointing DNS to the same VPS IP:

```bash
cd /root/bead-vpn-install
sudo ./update-domain.sh
```

## Check Status

```bash
systemctl status chaiya-ssh-api --no-pager
systemctl status bead-ws-ssh --no-pager
systemctl status nginx --no-pager
systemctl status dropbear --no-pager
```

## Notes

If only the IP changes but the domain stays the same, point the domain A record
to the new IP and run `install-bead-vpn-panel.sh` on the new VPS.

If only the domain changes on the same VPS, use `update-domain.sh`.
