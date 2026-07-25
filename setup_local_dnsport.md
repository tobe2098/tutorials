# Stealth MotionEye Surveillance Node over WireGuard (`rpi.home`)

This guide summarizes the working configuration for a **completely stealthy, "set-and-forget" surveillance node** on a Raspberry Pi running Ubuntu Server.

The Pi remains **100% dark and unresolvable on the physical local network (LAN)** while serving MotionEye via Nginx under the private domain **`rpi.home`** exclusively to connected WireGuard clients.

---

## 1. Architecture Overview

* **Physical LAN:** Completely stealthy. Avahi/mDNS is disabled to stop broadcasting hostnames, and Nginx is not bound to physical interfaces.
* **VPN Interface (`wg0`):** WireGuard tunnel providing standard unicast DNS (`dnsmasq`) and reverse-proxying web traffic (`Nginx`).
* **Services:**
* **MotionEye:** Listens internally on `10.8.0.1:8765`.
* **Nginx:** Binds strictly to `10.8.0.1:80` and `[fd00:db8:1::1]:80`.
* **`dnsmasq`:** Acts as the DNS server for VPN clients, resolving `rpi.home` to `10.8.0.1` / `fd00:db8:1::1`.



---

## 2. Raspberry Pi Setup (Server)

### Step 1: Disable LAN Broadcasts (Avahi / mDNS)

To prevent the Pi from advertising itself on physical Ethernet/Wi-Fi adapters, permanently stop and disable `avahi-daemon`:

```bash
sudo systemctl stop avahi-daemon
sudo systemctl disable avahi-daemon

```

### Step 2: Configure `dnsmasq` for Private Domain Resolution

Create or edit your `dnsmasq` config (e.g., `/etc/dnsmasq.d/rpi-home.conf`):

```conf
interface=wg0
listen-address=10.8.0.1
bind-interfaces

# Override .home queries locally
local=/home/

# Map rpi.home strictly to VPN tunnel IP addresses
address=/rpi.home/10.8.0.1
address=/rpi.home/fd00:db8:1::1

```

Restart `dnsmasq` to apply:

```bash
sudo systemctl restart dnsmasq

```

### Step 3: Configure Nginx Reverse Proxy

Ensure Nginx only listens on the WireGuard interfaces and proxies traffic to MotionEye. Edit `/etc/nginx/sites-available/motioneye`:

```nginx
server {
    listen 10.8.0.1:80;
    listen [fd00:db8:1::1]:80;
    server_name rpi.home;

    location / {
        proxy_pass http://10.8.0.1:8765;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

```

Validate and reload Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx

```

---

## 3. Thinkpad Client Setup (Ubuntu / NetworkManager)

### Step 1: Permanent NetworkManager Configuration

To force NetworkManager to route `.home` domain queries down the WireGuard tunnel (`wg1`) without breaking global internet DNS:

```bash
# Update NetworkManager connection DNS and routing domain
sudo nmcli connection modify wg1 ipv4.dns "10.8.0.1"
sudo nmcli connection modify wg1 ipv4.dns-search "~home"

# Reactivate the connection to apply
sudo nmcli connection up wg1

```

> **Note on Shell Syntax:** When passing routing domains in `zsh`, always wrap `"~home"` in quotes. Otherwise, `zsh` attempts home directory expansion for a non-existent user `home`.

### Step 2: Manual Runtime Command (Alternative / Testing)

If applying DNS settings on the fly without NetworkManager:

```bash
sudo resolvectl dns wg1 10.8.0.1
sudo resolvectl domain wg1 "~home"

```

---

## 4. Verification & Testing

### Test 1: Verify DNS Resolution on Client

Run `dig` on the client laptop:

```bash
dig rpi.home

```

**Expected Output:**

```text
;; ANSWER SECTION:
rpi.home.               0       IN      A       10.8.0.1

;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)

```

### Test 2: Test HTTP Connection

Run `curl` from the client laptop:

```bash
curl -I http://rpi.home

```

**Expected Output:**

```text
HTTP/1.1 200 OK
...

```

---

## 5. Key Troubleshooting & Design Lessons

1. **Why `.home` over `.local`:** RFC 6762 reserves `.local` strictly for Multicast DNS (mDNS). Modern Linux resolvers (`systemd-resolved`) actively block Unicast DNS servers (`dnsmasq`) from handling `.local` domains. Switching to `.home` (or `.internal`) completely resolves OS-level lookup failures.
2. **Physical Stealth:** Standard DNS/web servers bound to `0.0.0.0` leak physical presence. Restricting Nginx listeners to `10.8.0.1` and disabling `avahi-daemon` ensures zero footprint on the local router/LAN.
3. **Explicit Domain Search (`~home`):** The `~` prefix in systemd/NetworkManager instructs the resolver to use `10.8.0.1` **only** for queries matching `.home`, leaving all normal internet browsing unaffected.
