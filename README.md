# BEAD VPN Complete GitHub Package

Upload every file in this folder to the root of your GitHub repository.

Required files for one-file installer:

- bead-vpn-onefile-installer.sh
- app.py
- index.html
- sshws.html

Install example:

```bash
curl -fsSL https://raw.githubusercontent.com/benzvpn/bead-vpn/main/bead-vpn-onefile-installer.sh -o /tmp/bead-vpn.sh
sudo GITHUB_REPO=benzvpn/bead-vpn bash /tmp/bead-vpn.sh install vpn.example.com admin your-panel-password
```

If you do not have a domain yet:

```bash
curl -fsSL https://raw.githubusercontent.com/benzvpn/bead-vpn/main/bead-vpn-onefile-installer.sh -o /tmp/bead-vpn.sh
sudo GITHUB_REPO=benzvpn/bead-vpn bash /tmp/bead-vpn.sh install 1.2.3.4 admin your-panel-password n
```
