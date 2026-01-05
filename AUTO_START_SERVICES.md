# Auto-Start Services Configuration

## Services Running on Boot

### 1. Backend Server (FastAPI)
- **Service:** `com.chukwu.warehouse`
- **Config:** `~/Library/LaunchAgents/com.chukwu.warehouse.plist`
- **Port:** 8000
- **Working Directory:** `/Users/obinna.c/CascadeProjects/chukwu/backend`
- **Logs:** 
  - Output: `/Users/obinna.c/CascadeProjects/chukwu/logs/warehouse.log`
  - Errors: `/Users/obinna.c/CascadeProjects/chukwu/logs/warehouse.error.log`

### 2. Cloudflare Tunnel
- **Service:** `com.chukwu.cloudflared`
- **Config:** `~/Library/LaunchAgents/com.chukwu.cloudflared.plist`
- **Tunnel Name:** chukwu-warehouse
- **Domain:** warehouse.obinnachukwu.org
- **Logs:**
  - Output: `/Users/obinna.c/CascadeProjects/chukwu/logs/cloudflared.log`
  - Errors: `/Users/obinna.c/CascadeProjects/chukwu/logs/cloudflared.error.log`

## Management Commands

### Check Service Status
```bash
launchctl list | grep chukwu
```

### Restart Backend Server
```bash
launchctl kickstart -k gui/$(id -u)/com.chukwu.warehouse
```

### Restart Cloudflare Tunnel
```bash
launchctl kickstart -k gui/$(id -u)/com.chukwu.cloudflared
```

### Stop Services
```bash
launchctl stop com.chukwu.warehouse
launchctl stop com.chukwu.cloudflared
```

### Start Services
```bash
launchctl start com.chukwu.warehouse
launchctl start com.chukwu.cloudflared
```

### View Logs
```bash
# Backend logs
tail -f ~/CascadeProjects/chukwu/logs/warehouse.log

# Cloudflare logs
tail -f ~/CascadeProjects/chukwu/logs/cloudflared.log

# Error logs
tail -f ~/CascadeProjects/chukwu/logs/warehouse.error.log
tail -f ~/CascadeProjects/chukwu/logs/cloudflared.error.log
```

## Health Check
```bash
# Local backend
curl http://localhost:8000/health

# Live website
curl https://warehouse.obinnachukwu.org/health
```

## What Happens on Restart
1. **System boots/user logs in**
2. **LaunchAgents automatically start:**
   - Backend server starts on port 8000
   - Cloudflare tunnel connects to backend
3. **Website becomes accessible at warehouse.obinnachukwu.org**

Both services have `RunAtLoad=true` and `KeepAlive=true`, meaning they:
- Start automatically on boot/login
- Restart automatically if they crash
