# BEAD VPN GitHub Deploy

GitHub makes VPS installation easier. It does not replace DNS setup.
You still need to point the domain A record to the VPS IP before issuing SSL.

## Upload To GitHub

Create a GitHub repository, for example:

```text
bead-vpn
```

Upload these items to the repository:

```text
bead-vpn-install/
deploy-bead-vpn.ps1
install-github.sh
GITHUB_DEPLOY.md
```

## Install On New VPS

Replace:

- `yourname/bead-vpn` with your GitHub username and repository
- `vpn.example.com` with your domain
- `your-panel-password` with the panel password you want

Run on the VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/yourname/bead-vpn/main/install-github.sh -o /tmp/install-github.sh
sudo GITHUB_REPO=yourname/bead-vpn bash /tmp/install-github.sh vpn.example.com admin your-panel-password
```

Without SSL:

```bash
curl -fsSL https://raw.githubusercontent.com/yourname/bead-vpn/main/install-github.sh -o /tmp/install-github.sh
sudo GITHUB_REPO=yourname/bead-vpn bash /tmp/install-github.sh vpn.example.com admin your-panel-password n
```

## Install From Windows

You can also run this from PowerShell after downloading the repository:

```powershell
.\deploy-bead-vpn.ps1 -ServerIp 1.2.3.4 -Domain vpn.example.com -PanelUser admin -PanelPass "your-panel-password"
```
