**Gitea running as a single Go binary with an SQLite database** is the best choice.

When configured with SQLite, Gitea consumes only **30–50MB of RAM**, requires zero database services (no MySQL or PostgreSQL needed), and gives you a clean web interface to create repositories, view diffs, and manage SSH keys.

Here is how to set it up directly on your Raspberry Pi without Docker.

---

## Step 1: Create the System `git` User

Run this on your Raspberry Pi to create a dedicated, non-privileged system user for Git:

```bash
sudo adduser \
   --system \
   --shell /bin/bash \
   --gecos 'Git Version Control' \
   --group \
   --disabled-password \
   --home /home/git \
   git

```

---

## Step 2: Download the Gitea Binary

Download the latest 64-bit ARM (`arm64`) binary for the Raspberry Pi and move it into place:

```bash
# Download the arm64 Linux binary
wget -O gitea https://dl.gitea.com/gitea/1.22.6/gitea-1.22.6-linux-arm64

# Move binary to /usr/local/bin and make it executable
sudo mv gitea /usr/local/bin/gitea
sudo chmod +x /usr/local/bin/gitea

```

---

## Step 3: Create Directory Structure & Permissions

Create the storage directories for Gitea repositories and configuration files:

```bash
sudo mkdir -p /var/lib/gitea/{custom,data,log}
sudo chown -R git:git /var/lib/gitea/
sudo chmod -R 750 /var/lib/gitea/

sudo mkdir -p /etc/gitea
sudo chown -R git:git /etc/gitea
sudo chmod -R 770 /etc/gitea

```

---

## Step 4: Write Pre-Configured `app.ini`

To skip tedious installer forms and force Gitea to listen **strictly on loopback (`127.0.0.1`)**, create the configuration file manually:

```bash
sudo vi /etc/gitea/app.ini

```

Paste the following configuration:

```ini
APP_NAME = Private Stealth Git
RUN_USER = git
RUN_MODE = prod

[repository]
ROOT = /var/lib/gitea/data/gitea-repositories

[database]
DB_TYPE  = sqlite3
PATH     = /var/lib/gitea/data/gitea.db

[server]
PROTOCOL         = http
HTTP_ADDR        = 127.0.0.1
HTTP_PORT        = 3000
ROOT_URL         = http://git.home/
DISABLE_SSH      = false
SSH_PORT         = 22
START_SSH_SERVER = false

[security]
INSTALL_LOCK = true
SECRET_KEY   = ChangeThisToAnyRandomStringForSecurity12345!

[service]
DISABLE_REGISTRATION = false
REQUIRE_SIGNIN_VIEW  = true

```

Set permissions for the config file:

```bash
sudo chown git:git /etc/gitea/app.ini
sudo chmod 660 /etc/gitea/app.ini

```

---

## Step 5: Create a `systemd` Service

To ensure Gitea runs in the background and starts automatically on boot, create a service file:

```bash
sudo vi /etc/systemd/system/gitea.service

```

Paste the systemd definition:

```ini
[Unit]
Description=Gitea (Lightweight Git Server)
After=syslog.target
After=network.target

[Service]
RestartSec=2s
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea

[Install]
WantedBy=multi-user.target

```

Enable and start Gitea:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now gitea

```

Check that Gitea is active and running:

```bash
sudo systemctl status gitea

```

---

## Step 6: Create the Nginx Reverse Proxy Block

Now hook Gitea up to your existing stealth proxy setup.

Create `/etc/nginx/sites-available/gitea`:

```nginx
server {
    listen 10.8.0.1:80;
    listen [fd00:db8:1::1]:80;
    server_name git.home;

    # Allow larger repository pushes via HTTP
    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

```

Enable the site and reload Nginx:

```bash
sudo ln -s /etc/nginx/sites-available/gitea /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

```

---

## Step 7: Test from Your Thinkpad

Connect your Thinkpad to WireGuard (`wg1`) and test resolution and access:

```bash
# Verify wildcard DNS resolution
dig git.home

# Open in browser or curl:
curl -I http://git.home

```

When you open **`[http://git.home](http://git.home)`** in your browser, click **Register** to create your initial admin account!
