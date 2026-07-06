# TeslaMate Deploy — Troubleshooting

Load this file when any step in the SKILL.md workflow fails. Each section gives the symptom, the likely cause, and a concrete fix. The user can run the shell snippets themselves if the AI hasn't already tried them.

## 1. `install-teslamate.sh` errors

### `dpkg: error: dpkg frontend is locked by another process`

**Cause**: another `apt` is running (auto-update, snap, unattended-upgrades).

**Fix**:
```bash
# 等现有 apt 跑完
sudo lsof /var/lib/dpkg/lock-frontend
# 或强制解锁 (最后手段, 确认没有 apt 在跑)
sudo killall apt apt-get dpkg 2>/dev/null
sudo rm /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock 2>/dev/null
sudo dpkg --configure -a
```

### `E: Unable to fetch ... Could not resolve ...`

**Cause**: no DNS or no internet on the target host.

**Fix**:
```bash
ping -c2 8.8.8.8                    # 基础连通性
ping -c2 archive.ubuntu.com          # DNS + 域名
cat /etc/resolv.conf                # DNS 配置
# 临时换 DNS
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

### `permission denied` on Docker commands

**Cause**: current user not in the `docker` group, script falls back to `sudo docker`.

**Fix**: if `sudo docker` itself fails, passwordless sudo isn't configured. Either:
- Add the user to `docker` group: `sudo usermod -aG docker $USER` (logout/login required)
- Or configure passwordless sudo: `echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER`

### `docker compose version` returns "command not found"

**Cause**: installed `docker-compose` (v1) instead of `docker compose` (v2 plugin). The script checks for both, but some older images only have v1.

**Fix**:
```bash
# 装 v2 plugin (Ubuntu 22.04+)
sudo apt-get install -y docker-compose-v2
# 装 v1 binary (兜底)
sudo apt-get install -y docker-compose
```

## 2. Image pull problems

### `ERROR: pull access denied for ...` or `toomanyrequests`

**Cause**: hit Docker Hub rate limit, OR the configured mirror (`mirror.ccs.tencentyun.com`) is unreachable from the target host.

**Fix**:
```bash
# 看当前 mirror 配置
cat /etc/docker/daemon.json

# 测 mirror 是否通
curl -fsS -o /dev/null -w "tencent mirror: %{http_code}\n" https://mirror.ccs.tencentyun.com/v2/
curl -fsS -o /dev/null -w "docker hub: %{http_code}\n" https://registry-1.docker.io/v2/

# 换 mirror (比如用国内通用 mirror.aliyuncs.com)
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "registry-mirrors": [
    "https://mirror.aliyuncs.com",
    "https://mirror.ccs.tencentyun.com"
  ]
}
EOF
sudo systemctl restart docker

# 重试
cd ~/teslamate   # 远程是 /home/ubuntu/teslamate
sudo docker compose pull
```

### Pull hangs for >5 minutes, no progress

**Fix**:
```bash
# 中断当前 pull, 重启 docker daemon
sudo systemctl restart docker
# 单个 image 试拉, 确认网络
sudo docker pull postgres:17
```

## 3. Port conflicts

### `bind: address already in use` on 3000 / 4000 / 1883

**Find what's holding the port**:
```bash
sudo ss -ltnp | grep -E ':(3000|4000|1883) '
# 或
sudo lsof -i :3000 -i :4000 -i :1883
```

**Fix**: either stop the conflicting service, or change the host port in `docker-compose.yml` (e.g. `3001:3000`) and re-run `sudo docker compose up -d`. Note: changing the TeslaMate / Grafana port is fine, but Mosquitto on a non-default port means the TeslaMate container can't reach it via `mosquitto:1883` unless you also update the TeslaMate env. Easier to free the port.

## 4. Remote (SSH) problems

### `ssh: connect to host X.X.X.X port 22: Connection refused`

**Cause**: wrong IP, firewall blocking, or SSH on non-standard port.

**Fix**:
```bash
# 验证机器本身可达
ping -c2 X.X.X.X
# 测常见替代端口
nc -zv X.X.X.X 22 2>&1
nc -zv X.X.X.X 2222 2>&1
# 云服务商安全组需要在控制台放行 22 (出站默认通, 入站要放)
```

### `Permission denied (publickey)` on SSH

**Cause**: the deploy machine doesn't have a private key matching what's in `ubuntu@$server_ip:~/.ssh/authorized_keys`.

**Fix**: the user needs to add the deploy machine's public key to the server. Ask them to run (on the deploy machine):
```bash
cat ~/.ssh/id_ed25519.pub    # 或 id_rsa.pub
```
…then paste that into the server's `~/.ssh/authorized_keys`. If no key exists yet:
```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
ssh-copy-id ubuntu@X.X.X.X   # 首次需要输密码
```

### `Host key verification failed`

The script uses `ssh -o StrictHostKeyChecking=no` so this is unlikely, but if it happens it means SSH is rejecting the cipher/algorithm. Fix the server's `sshd_config` to allow modern algorithms, or pre-populate `known_hosts`:
```bash
ssh-keyscan -H X.X.X.X >> ~/.ssh/known_hosts
```

## 5. Post-install: container unhealthy

### TeslaMate returns 503 for the first 1–2 minutes

**Not actually a problem.** Postgres is doing its initial bootstrap. Re-check after 90 seconds:
```bash
sudo docker compose ps
sudo docker compose logs postgres | tail -30
```

### `docker compose ps` shows `Restarting` or `Exit 1`

**Fix**:
```bash
sudo docker compose logs <service-name>     # e.g. teslamate / postgres / grafana
# 常见: .env 文件没生成, 或 TM_ENCRYPTION_KEY 长度不够
cat ~/teslamate/.env    # 远程是 /home/ubuntu/teslamate/.env
# 重新生成 .env
cd ~/teslamate
sudo docker compose down
./install-teslamate.sh
```

### Grafana says "login attempt failed" after the user changed `admin/admin`

**Fix**: reset Grafana admin password via the official env var:
```bash
cd ~/teslamate
sudo docker compose stop grafana
# 在 docker-compose.yml 给 grafana 加一条 env:
#   - GF_SECURITY_ADMIN_PASSWORD=newpassword
sudo docker compose up -d grafana
# 登录后立刻在 UI 里把这个 env 删掉
```

## 6. Linking the Tesla account

### "Invalid refresh token"

**Cause**: most common cause is using a *legacy* token (the old auth flow that Tesla deprecated in 2023). User must re-generate.

**Fix**: walk the user through https://docs.teslamate.org/docs/guides/initial_setup — they need to log into `auth.tesla.com` (NOT `owner-api.teslamotors.com`) in a *normal browser session*, grab a fresh refresh token, and paste it into TeslaMate. The token is ~700 chars and starts with `eyJ…`.

### TeslaMate can fetch the car once, then "401 unauthorized" on the next refresh

**Cause**: Tesla's access tokens now expire in ~8h. The refresh token should auto-refresh; if it doesn't, the user's refresh token itself has been invalidated (Tesla rotates them occasionally).

**Fix**: re-grab a fresh refresh token from `auth.tesla.com` and re-paste it into TeslaMate's UI.

## 7. "It worked yesterday, now TeslaMate is down"

Walk through this in order:

```bash
sudo docker compose ps                   # 哪个挂了?
sudo docker compose logs --tail=200      # 最近的错误
df -h /                                  # 磁盘满了? Postgres 撑爆常见
free -h                                  # OOM?
sudo systemctl status docker             # docker daemon 还活着吗
# 重启整个 stack
cd ~/teslamate
sudo docker compose down
sudo docker compose up -d
```

If disk is full, the most common culprit is `mosquitto-data` or `postgres-data` volumes growing without bound. Check sizes with `sudo docker system df -v`.

## 8. Want to uninstall

```bash
# 停 stack + 删容器 + 删 volumes (数据会丢!)
cd ~/teslamate
sudo docker compose down -v
sudo docker image prune -a
# 远程的话: rm -rf /home/ubuntu/teslamate
```

Always confirm with the user before `-v` (deletes volumes = deletes database = loses all driving history).
