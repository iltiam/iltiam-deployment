
# Runbook 3: Cloudflare Tunnels for staging and production, cache and security rules (no public web ports)

- **Issue:** iltiam/iltiam-deployment#9 (DEP#9). **Decision record:** [ADR-0004](../adr/0004-hosting.md), Decision 4.
- **Who:** anyone on the team with Administrator rights on the Cloudflare account and admin rights on `iltiam/iltiam-deployment`. No cloud experience needed; follow the steps in order.
- **Time:** about 2 hours today. About 30 minutes more after Runbook 5 (#2) deploys the real stack (section 11).
- **Result:**
  - two tunnels, `iltiam-staging` and `iltiam-prod`, each with its own token in its GitHub Environment;
  - the four hostnames `app.`, `api.`, `staging-app.` and `staging-api.iltiamcare.com`, routed to the web and backend containers of their own Compose project, and **never** to the AI service;
  - cache rules that never cache the API;
  - one rate limit on sign-in, and two small firewall rules;
  - Cloudflare Access (email code) in front of `grafana.` and the backend's `/admin/`;
  - proof that the VM accepts nothing from outside but SSH.

> **This repository is public. Never paste a secret into this runbook, an issue, a PR, a commit or a chat.** That includes the tunnel token (a long string starting `eyJ`) and the `docker run … --token …` command that contains it. Never write the tunnel ID either: it is the long ID in the `….cfargotunnel.com` DNS target, in the tunnel's details, and in `cloudflared`'s logs. The same goes for the Cloudflare account ID and zone ID, the Zero Trust team name, the VM's public IP, and your own IP. **The dashboard's address bar contains the account ID, so never paste a dashboard URL.**

| Placeholder | Meaning |
|---|---|
| `<PUBLIC_IP>` | The VM's public IPv4 address (Runbook 1, section 6.2) |
| `<TEAM_NAME>` | The Zero Trust team name you choose in section 3.1. Not secret, but it is part of the account; keep it out of the repo |
| `<ADMIN_EMAIL_1>`, `<ADMIN_EMAIL_2>` | The two administrators' email addresses that may pass Cloudflare Access (ben-fatah, Omar-Nasri) |

Cloudflare redesigned its dashboard in 2025 and still moves menus. If a menu below is not where this says, type its name into the dashboard's search box.

## As built

Filled in when the steps are done. Names only: never a token, ID, team name or IP.

| Item | Value |
|---|---|
| Tunnels | `iltiam-staging` and `iltiam-prod` created |
| Published routes | `staging-app` → `web:8080`, `staging-api` → `backend-web:8000`, `app` → `web:8080`, `api` → `backend-web:8000`. Four proxied CNAMEs created; DoH shows DNSSEC validated |
| `CF_TUNNEL_TOKEN` in GitHub | Set in the `staging` and `production` Environments |
| Temporary test (section 5) | Staging test with stand-ins and production test (`cloudflared` only) run 2026-10-28 on the OCI VM, then torn down; Compose file removed from the VM; no containers left |
| Cache settings and rules | Browser Cache TTL "Respect Existing Headers", Always Online Off; Cache Rules `api-bypass`, `app-bypass-shell`, `app-cache-assets` active |
| Rate limiting rule | `auth-rate-limit` active; expression: 7-path list (section 7.1); fallback not needed |
| Custom rules | `block-scanners`, `app-read-only` active |
| `under-attack-app` | Configuration Rule created and disabled; `api-no-rewrites` (Runbook 2) active |
| Access login method and policy | Login method One-time PIN enabled. Reusable policy `team-only`: Allow, Include Emails `<ADMIN_EMAIL_1>`, `<ADMIN_EMAIL_2>`, session 24 h |
| Access applications | Self-hosted, `team-only`, One-time PIN only: `grafana` (`grafana.iltiamcare.com`, whole host), `api.iltiamcare.com` path `admin`, `staging-api.iltiamcare.com` path `admin` |
| OCI ingress and VM ports | Default Security List: the 3 ingress rules of section 10.1, one egress rule (all protocols to `0.0.0.0/0`); no NSG on the primary VNIC. VM: only `sshd` on `:22` publicly, Oracle's iptables kept, no containers. External port scan from the laptop: only 22 open |
| `NUM_PROXIES` | `1`, confirmed by the `whoami` headers (one `X-Forwarded-For` entry); behaviour on the real staging backend checked 2026-10-31 (row 27) |
| Real stack (section 11) | Staging, 2026-10-31: every check that doesn't need the web app passes (section 13). The web-dependent checks and HSTS moved to #35, the production checks to #36, `grafana.` to #10 |
| HSTS (Runbook 2, section 7) | Moved to #35: it waits until `staging-app` serves the real web app (iltiam/iltiam-web#25) |

## 1. How it works

```
 browser / phone ──HTTPS──▶  Cloudflare edge: TLS, cache rules, firewall rules, rate limit, Access
                                   ▲
                                   │  the tunnel: cloudflared dials OUT to Cloudflare (port 7844);
                                   │  nothing on the internet can dial in
 iltiam-1 ─────────────────────────┼───────────────────────────────────────────────────────────────
   Compose project iltiam-staging  │
     network "edge":     cloudflared ──▶ web:8080          (staging-app.iltiamcare.com)
                                     └─▶ backend-web:8000  (staging-api.iltiamcare.com)
     network "internal": backend-web, worker, beat, ai-api, ai-worker, postgres, redis
                         ai-api is not on "edge": cloudflared can't even resolve its name
   Compose project iltiam-prod: the same, with its own tunnel (app., api.iltiamcare.com)
```

- **No web ports, no certificates on the VM.** Cloudflare holds the certificate for `*.iltiamcare.com` (Runbook 2). The tunnel carries the traffic inside its own encrypted connection. So the VM's firewall stays closed to everything but SSH (section 10).
- **One tunnel per environment** ([ADR-0004](../adr/0004-hosting.md), Decision 3). Each Compose project (Runbook 5, #2) runs its own `cloudflared` container with its own token. Restarting or breaking staging never touches production's tunnel.
- **Remotely managed:** the routes live in the Cloudflare dashboard, not in a file on the VM. The container only needs its token.
- **Files never pass through Cloudflare:** photos, masks and PDFs go between the apps and OCI Object Storage by presigned links ([ADR-0004](../adr/0004-hosting.md), Decision 4).
- **Before Runbook 5 (#2) deploys the stack,** no `cloudflared` runs on the VM. The four hostnames then show Cloudflare's **error 1033** ("Cloudflare Tunnel error"). That is expected.

### Free plan limits we rely on

| Feature | Free plan | We use |
|---|---|---|
| Cloudflare Tunnel | free | 2 tunnels |
| Cache Rules | 10 | 3 |
| Custom rules (WAF) | 5 | 2 |
| Rate limiting rules | **1**: the expression can only use the URL **path** (not the hostname); counted per IP; 10-second period, 10-second block | 1, for sign-in, covering both environments |
| Configuration Rules | 10 | 2 (`api-no-rewrites` from Runbook 2, `under-attack-app`) |
| Cloudflare Access | up to 50 users | 2 people, 3 applications |

## 2. Before you start

- **Done already:** [Runbook 1](01-oci-account-and-vm.md) (the VM `iltiam-1`, `ssh iltiam` works), [Runbook 2](02-cloudflare-dns-tls.md) (the zone `iltiamcare.com`, Full (strict)) and [Runbook 4](04-secrets.md) (the GitHub Environments `staging` and `production`).
- The Cloudflare login, with 2FA (Runbook 2, section 2).
- **Git Bash** with the GitHub CLI: `gh auth status` says "Logged in to github.com".
- **PowerShell** for the checks from your laptop. `curl.exe` comes with Windows 10/11; type `curl.exe`, not `curl`, which PowerShell maps to something else.
- The repository checked out on your laptop, for `scripts/tunnel-test.compose.yml` (section 5).
- `<ADMIN_EMAIL_1>` and `<ADMIN_EMAIL_2>` for Access (section 9).

## 3. The two tunnels

### 3.1 Zero Trust, the first time only

1. Account home → **Zero Trust.**
2. If Cloudflare asks you to set up Zero Trust:
   - choose a **team name** (`<TEAM_NAME>`, for example the project name; it becomes the address of the Access login page);
   - choose the **Free** plan. If it asks for a payment card for the $0 plan, add one; the Free plan is not charged.

**What you should see:** the Zero Trust overview page, with the Free plan shown under **Settings → Account** (or **Billing**).

### 3.2 Create `iltiam-staging` and store its token

1. **Networking → Tunnels.** In the Zero Trust dashboard it is **Networks → Connectors → Cloudflare Tunnels** (older dashboards: **Networks → Tunnels**).
2. **Create a tunnel → Cloudflared** → name `iltiam-staging` → **Save tunnel.**
3. The next page, **Install and run connectors**, offers one command per operating system. Choose **Docker.** It shows:

   ```
   docker run cloudflare/cloudflared:latest tunnel --no-autoupdate run --token eyJ…
   ```

   **Don't run this command anywhere.** Our container comes from Compose (Runbook 5). We only need the token: the text after `--token`.
4. Copy the whole command (the copy button next to it). In **Git Bash**, from any folder, paste it at the prompt of the first line below and press Enter. Nothing is shown while you paste. The second line keeps only the token, the part after the last space, and sends it to GitHub:

   ```bash
   read -rsp 'Paste the docker run command: ' CMD; echo
   printf '%s' "${CMD##* }" | gh secret set CF_TUNNEL_TOKEN --env staging -R iltiam/iltiam-deployment
   unset CMD; clear
   ```

   Then copy any harmless text, so the command no longer sits in your clipboard. If Windows clipboard history is on (Win+V), delete the entry there.
5. Back in the dashboard → **Next** to the route page. Continue with section 4.1.

**What you should see:** `✓ Set Actions secret CF_TUNNEL_TOKEN for iltiam/iltiam-deployment`, and `iltiam-staging` in the tunnel list with status **Inactive** (or **Down**): no connector runs yet.

**The token can be shown again:** tunnel → **Edit** (or **Configure**) → **Overview** shows the same install command. So it needs no Bitwarden escrow ([Runbook 4](04-secrets.md), section 11).

### 3.3 Create `iltiam-prod` the same way

Repeat section 3.2 with the name `iltiam-prod` and `--env production` in the `gh secret set` line.

**What you should see:**

```bash
gh secret list --env staging -R iltiam/iltiam-deployment
gh secret list --env production -R iltiam/iltiam-deployment
```

Both lists include `CF_TUNNEL_TOKEN` (with a date; the value can't be read back).

## 4. Published application routes

A **published application route** (older dashboards: **public hostname**) sends one hostname to one service inside the Compose project. `web` and `backend-web` are the Compose service names; `cloudflared` reaches them by name on the project's `edge` network.

| Tunnel | Subdomain | Domain | Path | Service type | URL |
|---|---|---|---|---|---|
| `iltiam-staging` | `staging-app` | `iltiamcare.com` | (empty) | HTTP | `web:8080` |
| `iltiam-staging` | `staging-api` | `iltiamcare.com` | (empty) | HTTP | `backend-web:8000` |
| `iltiam-prod` | `app` | `iltiamcare.com` | (empty) | HTTP | `web:8080` |
| `iltiam-prod` | `api` | `iltiamcare.com` | (empty) | HTTP | `backend-web:8000` |

- **Ports:** the backend listens on 8000 (backend `Dockerfile`, `docker/entrypoint.sh`). The web image's port is **8080, TO CONFIRM** with WEB-03 (iltiam/iltiam-web#25), which builds that image (tracked in #35). If WEB-03 picks another port, edit the two `web` routes (tunnel → **Published application routes** → **⋮ → Edit**).
- **HTTP, not HTTPS, inside the VM** is correct: the traffic between the containers never leaves the VM's Docker network, and the tunnel itself is encrypted.
- **Nothing routes to the AI service.** There is no route for `ai-api`, and Runbook 5 keeps it off the `edge` network.
- **Everything else gets 404.** A remotely managed tunnel ends its rules with a catch-all `http_status:404`, so a request that matches no route gets a 404, never another service.

### 4.1 Staging

1. Route page from section 3.2 step 5, or later: **Tunnels** → `iltiam-staging` → **Edit** → **Published application routes → Add a published application route.**
2. Fill in the first `iltiam-staging` row of the table. Leave **Additional application settings** as they are. In particular, leave **HTTP Host Header** empty, so the backend sees the real hostname (`ALLOWED_HOSTS`).
3. **Save.** Add the second `iltiam-staging` row the same way.

### 4.2 Production

The same for `iltiam-prod`, with the two production rows.

**What you should see:**

- Each tunnel lists exactly its **two** routes, and nothing else.
- **DNS → Records** of `iltiamcare.com` has four new **CNAME** records, `app`, `api`, `staging-app` and `staging-api`, each **Proxied** (orange cloud), with a target ending in `.cfargotunnel.com`. Cloudflare made them; don't edit them, and don't paste their targets anywhere (they contain the tunnel ID).
- **SSL/TLS → Edge Certificates:** the **Universal** certificate for `iltiamcare.com, *.iltiamcare.com` turns **Active** within minutes to a few hours of the first proxied record. Record it as row 11 of [Runbook 2](02-cloudflare-dns-tls.md)'s checklist.
- Opening `https://staging-app.iltiamcare.com` in a browser shows Cloudflare's **error 1033** until a connector runs. That is expected (section 5 and Runbook 5).

**DNS from your laptop** (PowerShell). The first line asks Cloudflare's resolver directly; the second goes over HTTPS, for networks that block DNS to outside resolvers:

```powershell
Resolve-DnsName staging-api.iltiamcare.com -Type A -Server 1.1.1.1 | Where-Object Type -eq "A" | Select-Object Name, IPAddress
foreach ($h in "app","api","staging-app","staging-api") { $r = Invoke-RestMethod -Uri "https://cloudflare-dns.com/dns-query?name=$h.iltiamcare.com&type=A" -Headers @{accept="application/dns-json"}; "== $h  DNSSEC-validated=$($r.AD)"; $r.Answer | Where-Object type -eq 1 | ForEach-Object { $_.data } }
```

**What you should see:** for each of the four names, two or more IPv4 addresses (Cloudflare's, often starting `104.` or `172.`), and `DNSSEC-validated=True`. Both commands print only A records, so no tunnel ID appears. Don't add `-Type CNAME` output to the issue: the CNAME target is the tunnel ID.

## 5. Temporary test on the VM (before Runbook 5)

**Nothing permanent runs on the VM for this runbook.** The real `cloudflared` containers come with Runbook 5 (#2). This short test proves now, before the stack exists, that:

- each token works, and the tunnel shows **Healthy** in the dashboard;
- containers on the VM can reach Cloudflare (Oracle's firewall rules don't block them);
- the routes, the certificate, the cache rules and the firewall rules work end to end (staging only);
- which headers reach the backend, which sets `NUM_PROXIES` (section 8).

A tunnel shows **Healthy** as soon as one `cloudflared` is connected, whether or not anything answers behind it. So production is tested with the connector alone.

[`scripts/tunnel-test.compose.yml`](../../scripts/tunnel-test.compose.yml) has:

- `cloudflared` (pinned version);
- two **stand-ins**, only with the `stand-ins` profile, under the real service names:
  - `web` is nginx's welcome page on port 8080;
  - `backend-web` is `traefik/whoami` on port 8000, which answers every request with the request's own headers.

### 5.1 Staging, with the stand-ins

Do sections 6, 7 and 9 first if you want to check them in the same run (rows 10, 12, 13 and 16 of section 13). The test works without them too.

1. From the repository folder on your laptop (Git Bash):

   ```bash
   scp scripts/tunnel-test.compose.yml iltiam:~
   ssh iltiam
   ```

2. On the VM, read the staging token without showing it. Copy the **staging** install command again (**Tunnels → `iltiam-staging` → Edit → Overview**, Docker), paste it at the prompt, then press Enter:

   ```bash
   read -rsp 'Paste the docker run command: ' CMD; echo
   export TUNNEL_TOKEN="${CMD##* }"; unset CMD
   echo "length ${#TUNNEL_TOKEN}, starts ${TUNNEL_TOKEN:0:3}"
   ```

   **What you should see:** `length` around 180 to 250, `starts eyJ`. Anything else: run the two lines again.
3. Start it, then forget the token in this shell:

   ```bash
   docker compose -f ~/tunnel-test.compose.yml --profile stand-ins up -d
   unset TUNNEL_TOKEN
   docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
   docker logs tunnel-test-cloudflared-1 2>&1 | grep -ci "registered tunnel connection"
   ```

   **What you should see:** three pulls the first time, `Container tunnel-test-… Started` three times; `docker ps` lists the three `tunnel-test-…` containers **Up**, with an empty port column; the count is **`4`** (the four connections to Cloudflare). If it says less, wait a few seconds and run the last line again.

   After `unset TUNNEL_TOKEN`, use plain `docker ps` and `docker logs` as above, not `docker compose ps` or `logs`: the Compose file requires `TUNNEL_TOKEN` for every `docker compose` command (section 14).
4. Dashboard → **Tunnels:** `iltiam-staging` is **Healthy**, with 1 connector.
5. Run the checks in section 5.3 from your laptop, then remove the test (section 5.4).

### 5.2 Production, connector only

Same as 5.1, but with the **production** install command (`iltiam-prod`) at the prompt, and **without** the profile, so only `cloudflared` starts:

```bash
read -rsp 'Paste the docker run command: ' CMD; echo
export TUNNEL_TOKEN="${CMD##* }"; unset CMD
docker compose -f ~/tunnel-test.compose.yml up -d
unset TUNNEL_TOKEN
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker logs tunnel-test-cloudflared-1 2>&1 | grep -ci "registered tunnel connection"
```

**What you should see:**

- only `Container tunnel-test-cloudflared-1 Started`; `docker ps` lists only `tunnel-test-cloudflared-1`, with an empty port column; the count is `4`;
- `iltiam-prod` **Healthy** in the dashboard;
- `https://app.iltiamcare.com` and `https://api.iltiamcare.com` answer **502 Bad Gateway**: the connector runs, but nothing is behind it. Once the test is removed they return to **error 1033**. **The production hostnames stay at 502 or 1033 until Runbook 5 (#2) deploys production.**

Then remove the test (section 5.4).

### 5.3 Checks from your laptop (staging test running)

PowerShell. Write down pass or fail; never paste the output itself into the issue, because it contains your IP.

```powershell
curl.exe -sI https://staging-app.iltiamcare.com/
```

**What you should see:** `HTTP/1.1 200 OK` (or `HTTP/2 200`), `server: cloudflare`, and `cf-cache-status: DYNAMIC`. That is nginx's welcome page, over Cloudflare's certificate.

```powershell
curl.exe -s https://staging-api.iltiamcare.com/api/health/
curl.exe -s -H "X-Forwarded-For: 203.0.113.7" https://staging-api.iltiamcare.com/api/health/
```

**What you should see:** `whoami` echoes the request. Look for these lines:

- `GET /api/health/ HTTP/1.1` and `Host: staging-api.iltiamcare.com`. The hostname arrives unchanged.
- First command: `X-Forwarded-For: <your IP>`, **one** address. Second command: `X-Forwarded-For: 203.0.113.7, <your IP>`. The address you sent comes first, the real one last. This is what sets `NUM_PROXIES` to `1` (section 8).
- `X-Forwarded-Proto: https`.
- `Cf-Connecting-Ip: <your IP>`.

The remaining checks of this test are rows 10, 12, 13 and 16 of section 13. Each of them names its command.

### 5.4 Remove the test

On the VM, the same for both tests. `TUNNEL_TOKEN=unused` only satisfies the Compose file's check; `down` needs no real token:

```bash
TUNNEL_TOKEN=unused docker compose -f ~/tunnel-test.compose.yml --profile stand-ins down
rm ~/tunnel-test.compose.yml
docker ps -a --filter name=tunnel-test
```

**What you should see:** `Removed` lines, then an empty table (only the header line). Within a minute, the tunnel goes back to **Inactive** (or **Down**) in the dashboard, and its hostnames show error 1033.

The test's containers only kept the token in memory and in their own settings. Both are gone with `down`.

## 6. Cache

The rules, in short:

- **API hosts (`api.`, `staging-api.`):** never cached, any path.
- **App hosts (`app.`, `staging-app.`):** only `/assets/*` is cached. Those files carry a content hash in their names (Vite), so a new deploy gets new names and nothing stale is ever served.
- **Everything else on the app hosts** (`/`, `/index.html`, `/config.js` and every page route) is not cached. `/config.js` matters most: it carries the API address per environment (WEB-03), and Cloudflare would cache it by default because it ends in `.js`.
- **Anything a signed-in user receives is never cached.** All API calls, including every response that needs a sign-in, go to the API hosts, which are never cached. The app hosts serve only public files.

### 6.1 Zone settings

**Caching → Configuration:**

| Setting | Value | Why |
|---|---|---|
| Browser Cache TTL | **Respect Existing Headers** | The backend and the web image decide how browsers cache, not Cloudflare |
| Always Online | **Off** | It would show an old copy of the app when the VM is down: wrong for a medical app |
| Development Mode | Off | Only for debugging; it turns itself off after 3 hours |

### 6.2 Cache Rules

**Caching → Cache Rules → Create rule.** In the new dashboard: **Rules → Overview → Create rule → Cache Rule.** For each rule: **Rule name**, then **Custom filter expression → Edit expression**, paste the expression, set the action, **Deploy.**

The three rules never match the same request, so their order doesn't matter.

1. **`api-bypass`**

   ```
   (http.host in {"api.iltiamcare.com" "staging-api.iltiamcare.com"})
   ```

   **Cache eligibility: Bypass cache.**

2. **`app-bypass-shell`**

   ```
   (http.host in {"app.iltiamcare.com" "staging-app.iltiamcare.com"} and not starts_with(http.request.uri.path, "/assets/"))
   ```

   **Cache eligibility: Bypass cache.**

3. **`app-cache-assets`**

   ```
   (http.host in {"app.iltiamcare.com" "staging-app.iltiamcare.com"} and starts_with(http.request.uri.path, "/assets/"))
   ```

   - **Cache eligibility: Eligible for cache.**
   - **Edge TTL: Use cache-control header if present**, use default Cloudflare caching behavior if not.
   - **Browser TTL: Respect origin TTL.**

**What you should see:** the three rules in the Cache Rules list, all enabled.

**What the web image must send** (WEB-03, iltiam/iltiam-web#25): `Cache-Control: no-cache` for `/index.html` and `/config.js`, and a long `max-age` with `immutable` for `/assets/*`. Cloudflare follows those headers (rule 3).

**After a deploy, nothing needs purging:** the page shell is never cached, and new assets have new names. If you ever must, **Caching → Configuration → Purge Cache → Custom Purge** by URL; never purge everything during working hours.

## 7. Security rules

[Runbook 2](02-cloudflare-dns-tls.md) already set: Bot Fight Mode **off** (section 9.1), and Rocket Loader and Email Obfuscation **off** for the zone, plus the `api-no-rewrites` rule for the API hosts (section 8). This runbook only adds the three items below, and checks those settings once the hostnames exist (section 13, row 25).

### 7.1 Rate limit on sign-in

The Free plan allows **one** rate limiting rule. It can only look at the URL **path**, so it covers staging and production together, which is fine. It is a coarse outer limit: the backend has its own, stricter per-IP limit for sign-in (20 a minute) and answers with its normal JSON error. Cloudflare only stops floods.

The rule lists the sign-in and password paths one by one. A rule on all of `/api/auth/*` would also count token refreshes (`/api/auth/token/refresh/`) and profile reads (`/api/auth/me/`), which a normal session sends all the time.

1. **Security → Security rules → Create rule → Rate limiting rule.** In the old dashboard: **Security → WAF → Rate limiting rules → Create rule.**
2. **Rule name:** `auth-rate-limit`.
3. **Custom filter expression → Edit expression:**

   ```
   (http.request.uri.path in {"/api/auth/login/" "/api/auth/login/verify/" "/api/auth/login/resend/" "/api/auth/password/reset/request/" "/api/auth/password/reset/confirm/" "/api/auth/activate/" "/api/auth/activate/authenticator/"})
   ```

4. **With the same characteristics:** IP (the only choice on Free).
5. **When rate exceeds:** **10** requests per **10 seconds**.
6. **Then take action:** **Block**, for **10 seconds** (the only duration on Free).
7. **Deploy.**

**If the form refuses the expression** (some Free-plan forms only offer simple operators on the path), use this one instead. It still covers the three sign-in steps, which matter most:

```
(starts_with(http.request.uri.path, "/api/auth/login"))
```

If `starts_with` is refused too, build it in the form: **Field** URI Path, **Operator** starts with (or wildcard `/api/auth/login*`). Write in the As built table which version you used.

**What you should see:** `auth-rate-limit` enabled in the list.

**Many users behind one address:** a clinic's network often shows one public IP for everyone. Ten sign-in steps in ten seconds is still far above what a clinic does by hand. If **Security → Events** ever shows `auth-rate-limit` blocking real users, raise the number; don't remove the rule.

### 7.2 Custom rules (WAF)

Two small rules. The Free plan allows five.

**Security → Security rules → Create rule → Custom rule** (old dashboard: **Security → WAF → Custom rules → Create rule**). Expression, action **Block**, **Deploy.**

1. **`block-scanners`:** bots probing for leaked files and other software. Nothing of ours has these paths.

   ```
   (http.request.uri.path contains "/.env" or http.request.uri.path contains "/.git" or starts_with(http.request.uri.path, "/wp-") or http.request.uri.path contains ".php")
   ```

2. **`app-read-only`:** the app hosts only serve files. All writes go to the API hosts.

   ```
   (http.host in {"app.iltiamcare.com" "staging-app.iltiamcare.com"} and not http.request.method in {"GET" "HEAD"})
   ```

**What you should see:** both rules enabled. **Security → Events** later shows what they blocked.

### 7.3 Under Attack, for the app hosts only

[Runbook 2, section 9.3](02-cloudflare-dns-tls.md) explains Under Attack mode, and why it must never cover the API hosts: the mobile app can't pass its challenge page. Now that the hostnames exist, create its Configuration Rule **in advance, disabled**, so turning it on during an HTTP flood is one click:

1. **Rules → Configuration Rules → Create rule** (new dashboard: **Rules → Overview → Create rule → Configuration Rule**).
   - Rule name: `under-attack-app`.
   - Expression:

     ```
     (http.host in {"app.iltiamcare.com" "staging-app.iltiamcare.com"})
     ```

   - **+ Add → I'm Under Attack → On.**
   - **Deploy.**
2. In the Configuration Rules list, switch `under-attack-app` **off**.

**What you should see:** `api-no-rewrites` (on) and `under-attack-app` (**off**). When to turn it on, and the whole-zone last resort: Runbook 2, section 9.3.

## 8. What the backend sees: `NUM_PROXIES` and `FORWARDED_ALLOW_IPS`

A request passes **one** proxy that edits its headers: Cloudflare's edge. `cloudflared` forwards the headers unchanged. The test in section 5.3 shows what arrives:

- `X-Forwarded-For` has the visitor's real address as its **last** entry. Anything the visitor sent comes before it.
- `X-Forwarded-Proto: https`.
- The TCP connection comes from the `cloudflared` container, never from the visitor.

So:

- **`NUM_PROXIES=1`**, an Environment variable in both environments ([Runbook 4](04-secrets.md), section 9). The backend's per-IP rate limits (Django REST framework) then use the last `X-Forwarded-For` entry, the address Cloudflare saw. A visitor can't dodge the limit by sending a fake header.
  - With `0`, every visitor would look like the `cloudflared` container and share **one** limit.
  - With `2`, the visitor's own fake entry would count.

  Set it once the test showed one entry for a plain request:

  ```bash
  gh variable set NUM_PROXIES --env staging --body 1 -R iltiam/iltiam-deployment
  gh variable set NUM_PROXIES --env production --body 1 -R iltiam/iltiam-deployment
  ```

- **`FORWARDED_ALLOW_IPS`** (a constant in `compose.yml`, Runbook 5, #2): gunicorn trusts `X-Forwarded-Proto` only from these addresses, and its default is `127.0.0.1`. `cloudflared` reaches the backend from its own container address, which Docker picks. Runbook 5 sets it to `*` in `compose.yml`. That is safe because nothing but `cloudflared` and `web` can reach `backend-web`: there are no published ports, and the AI and database containers are not on the `edge` network. Django already trusts the header (`SECURE_PROXY_SSL_HEADER`), so this only keeps gunicorn's own view of the scheme the same.

## 9. Cloudflare Access (email one-time code)

Access puts a Cloudflare sign-in page in front of a hostname or a path. On the Free plan we use the **one-time PIN** method:
- the person types their email address;
- if the address is on the allow list, Cloudflare emails a 6-digit code;
- if it isn't, no code is sent.

Three applications, one policy:

| Application | Protects | Why |
|---|---|---|
| `grafana` | `grafana.iltiamcare.com` | Monitoring (Runbook 7, #10). Created **now**, so it is protected the moment #10 adds its route |
| `django-admin-prod` | `api.iltiamcare.com/admin` | The backend serves Django's admin site at `/admin/`. It has its own login, but it never needs to be open to the internet |
| `django-admin-staging` | `staging-api.iltiamcare.com/admin` | The same for staging |

**The staging hosts are not behind Access.** The mobile staging builds and demos call `staging-api` directly, and Access would block them. Staging holds only test accounts.

### 9.1 Login method

Zero Trust → **Settings → Authentication → Login methods** (newer dashboards: **Integrations → Identity providers**).

**What you should see:** **One-time PIN** in the list. It is there by default. If not: **Add new → One-time PIN → Save.**

### 9.2 The policy `team-only`

1. Zero Trust → **Access → Policies** (newer dashboards: **Access controls → Policies**) → **Add a policy.**
2. **Policy name:** `team-only`. **Action:** **Allow.** **Session duration:** 24 hours.
3. **Add rules → Include → Selector: Emails →** `<ADMIN_EMAIL_1>`, `<ADMIN_EMAIL_2>`.
4. **Save.**

To give someone else access later, add their address here: all three applications use this one policy.

### 9.3 The `grafana` application

1. **Access → Applications** (newer: **Access controls → Applications**) → **Add an application → Self-hosted.**
2. **Application name:** `grafana`. **Session duration:** 24 hours.
3. **Add public hostname** (or **Application domain**): subdomain `grafana`, domain `iltiamcare.com`, path empty.
4. **Policies → Select existing policies →** `team-only`.
5. **Login methods:** One-time PIN. If there is an **Instant Auth** option, turn it on (it skips the page that lists login methods).
6. **Next** through the remaining pages, keeping the defaults → **Save.**

Cloudflare may warn that `grafana.iltiamcare.com` has no DNS record yet. That is expected: #10 adds it. **Which tunnel carries `grafana.` is decided in #10.**

### 9.4 The two `/admin` applications

The same as 9.3, twice:

| Application name | Subdomain | Domain | Path |
|---|---|---|---|
| `django-admin-prod` | `api` | `iltiamcare.com` | `admin` |
| `django-admin-staging` | `staging-api` | `iltiamcare.com` | `admin` |

Policy `team-only`, login method One-time PIN.

**The path must be filled in.** An application on `api.iltiamcare.com` without a path would put the sign-in page in front of the whole API, and the mobile and web apps would stop working.

**What you should see:** three applications under **Access → Applications**, each with the `team-only` policy. Checks: section 13, rows 15 to 17.

## 10. No public web ports

The VM must accept nothing from the internet but SSH. Two firewalls do that, and Compose must not open a third way in.

### 10.1 OCI: the security list, and no extra NSG

1. **☰ → Networking → Virtual cloud networks → `iltiam-vcn` → Security → Default Security List for iltiam-vcn → Ingress rules.** Set the compartment filter on the left to **root**: the list stayed there when the VCN moved (Runbook 1, section 6.4).
2. The only rules must be:

   | Source | Protocol | Destination port |
   |---|---|---|
   | `0.0.0.0/0` | TCP | 22 |
   | `0.0.0.0/0` | ICMP | type 3, code 4 |
   | `10.0.0.0/16` | ICMP | type 3 |

   Delete any rule for 80, 443 or another port.
3. **Egress rules:** keep the default **all traffic to `0.0.0.0/0`**. `cloudflared` needs outbound port 7844 (TCP and UDP) to Cloudflare, and the VM needs 443 for updates and images.
4. **☰ → Compute → Instances → `iltiam-vm`** (the VM's hostname is `iltiam-1`) **→ Networking → Attached VNICs →** the primary VNIC **→ Network security groups.**

**What you should see:** exactly the three ingress rules above, and **no** network security group on the VNIC (or only one with no ingress rule other than TCP 22).

**Result (2026-10-28): PASS.**
- Ingress: exactly the three rules above. No web or database ports.
- Egress: one rule, all protocols to `0.0.0.0/0`.
- No NSG attached to the primary VNIC.

### 10.2 The VM's own firewall

Oracle's Ubuntu image ships iptables rules (`/etc/iptables/rules.v4`) that let in only port 22 (Runbook 1, section 12).
- **Keep them.** Don't flush them.
- **Don't install or enable `ufw`.** It fights both Oracle's rules and Docker's.

**For Runbook 5 (#2): no `ports:` in any Compose file.** A port that Docker publishes goes around the iptables input rules. The OCI security list would still block it, but we don't rely on one layer. The containers talk to each other on Docker networks, and the internet reaches them only through the tunnel.

### 10.3 SSH stays on port 22 (for v1.0)

SSH could also go through a tunnel, with Cloudflare Access in front and port 22 closed. **Not now:**

- The `cloudflared` containers live inside the Compose projects. If a stack is down, SSH through the tunnel is down too, and the only way back in is Oracle's slow serial console. SSH through a tunnel needs its own `cloudflared` on the VM itself (a system service), separate from Compose.
- The deploy workflow (Runbook 9, DEP-03) logs in by SSH from GitHub's runners. Through Access, each runner would need `cloudflared` and an Access service token: one more secret to keep and rotate.
- Port 22 is already key-only, root can't log in, and fail2ban bans brute-force sources (Runbook 1, section 9).

So SSH stays on public port 22 for v1.0 ([ADR-0004](../adr/0004-hosting.md), Decision 4). SSH through the tunnel is a later hardening step, with its own issue.

### 10.4 Check that only SSH is open

**On the VM** (`ssh iltiam`):

```bash
sudo ss -tlnp
sudo iptables -S INPUT
docker ps --format '{{.Names}}  {{.Ports}}'
```

**What you should see:**
- `ss`: on a public address, only `0.0.0.0:22` and `[::]:22`. Anything else listens only on `127.0.0.x` (for example `127.0.0.53:53`).
- `iptables`: an `ACCEPT` rule for `--dport 22`, and a `REJECT` rule after it.
- `docker ps`: today nothing, or the test containers with an empty port column. After Runbook 5, no line may show `0.0.0.0:` or `[::]:`.

**Result on the VM (2026-10-28): PASS.**
- `ss -tlnp`: publicly only `sshd` on `0.0.0.0:22` and `[::]:22`; `systemd-resolved` on loopback only.
- `iptables -L INPUT`: ESTABLISHED/RELATED, ICMP, loopback and TCP 22 accepted, then `REJECT`.
- `docker ps`: no containers running.

**From your laptop.** Run this in **Windows PowerShell on the laptop**: not in Git Bash, and not inside the SSH session (from the VM itself the scan proves nothing). Connect the laptop to a **phone hotspot**, not the King Saud University network (section 14). It takes a few minutes, because each closed port waits for a timeout:

```powershell
foreach ($p in 22,80,443,111,2000,3000,5432,6379,7844,8000,8080,9090) { "{0,5}  {1}" -f $p, (Test-NetConnection <PUBLIC_IP> -Port $p -WarningAction SilentlyContinue).TcpTestSucceeded }
```

**What you should see:** `22  True`. Every other line ends in `False`.

**The same from Git Bash** on the laptop. Type the VM's public IP at the prompt; it takes about a minute:

```bash
read -rp 'VM public IP: ' IP; for p in 22 80 443 111 2000 3000 5432 6379 7844 8000 8080 9090; do if timeout 5 bash -c "exec 3<>/dev/tcp/$IP/$p" 2>/dev/null; then echo "$p open"; else echo "$p closed"; fi; done; unset IP
```

**What you should see:** `22 open`, every other line `closed`. If one port shows `open` on the King Saud University network, see section 14.

**Optional: a full scan of all 65,535 ports**, with Docker Desktop running on your laptop (Oracle's testing policy allows scanning your own instances):

```powershell
docker run --rm instrumentisto/nmap:7.98-r2 -Pn -p- --min-rate 500 <PUBLIC_IP>
```

**What you should see:** after a few minutes, `22/tcp open ssh` and nothing else open (all others "filtered").

**Result from the laptop (2026-10-28): PASS.** The `Test-NetConnection` loop in Windows PowerShell gave `22 True`; 80, 443, 111, 3000, 5432, 6379, 8000, 8080 and 9090 gave `False`. Ports 2000 and 7844 were not in the loop: not tested (no listener on the VM; `ss` shows only 22).

**Result with the staging stack running (2026-10-31): PASS.**
- On the VM: publicly only `sshd` on `:22` (`systemd-resolved` on `127.0.0.53`, local only); iptables accepts 22, then `REJECT`; no published container ports.
- From the laptop (Git Bash loop, King Saud University network): `22 open`; 80, 443, 111, 3000, 5432, 6379, 7844, 8000, 8080 and 9090 `closed`. 2000 showed `open` because the university network answers port 2000 itself (section 14); nothing listens on it on the VM.

Run both checks again once production runs too (#36).

## 11. After Runbook 5 (#2): the real stack, then HSTS

When Runbook 5 has deployed staging (and later production), the stand-ins are replaced by the real containers. Run these checks, rows 22 to 28 of section 13.

- **Staging:** done on 2026-10-31 for everything that doesn't need the web app.
- **The web app's checks and HSTS** (rows 22 and 25 for the app hosts, 24, 28) wait for iltiam/iltiam-web#25 and are tracked in #35.
- **Production** (`app.` and `api.`) is tracked in #36.

### 11.1 The four hostnames

```powershell
curl.exe -s https://staging-api.iltiamcare.com/api/health/
curl.exe -sI https://staging-app.iltiamcare.com/
```

**What you should see:** `{"status": "ok"}`, then `200` with `cf-cache-status: DYNAMIC` (or `BYPASS`) and a `content-security-policy` header. The web image's nginx sends the content security policy (WEB-03), not Cloudflare.

### 11.2 Cache, for real

```powershell
1..2 | ForEach-Object { curl.exe -sI https://staging-api.iltiamcare.com/api/health/ | Select-String "cf-cache-status" }
if ((curl.exe -s https://staging-app.iltiamcare.com/) -match '/assets/[^"]+\.js') { $a = $Matches[0]; 1..2 | ForEach-Object { curl.exe -sI "https://staging-app.iltiamcare.com$a" | Select-String "cf-cache-status" } }
curl.exe -sI https://staging-app.iltiamcare.com/config.js | Select-String "cf-cache-status|cache-control"
```

**What you should see:**
- API: `DYNAMIC` (or `BYPASS`) both times.
- The asset: `MISS` then `HIT` (`EXPIRED` or `REVALIDATED` also mean it is cached).
- `/config.js`: `DYNAMIC` (or `BYPASS`) and `cache-control: no-cache`.

### 11.3 No rewriting, no injected scripts

```powershell
curl.exe -s https://staging-app.iltiamcare.com/ | Select-String "rocket-loader|email-decode|cloudflareinsights"
curl.exe -s https://staging-api.iltiamcare.com/api/health/ | Select-String "rocket-loader|email-decode|cloudflareinsights"
```

**What you should see:** no output at all. `cloudflareinsights` would mean Cloudflare Web Analytics injects its script into the pages, which the content security policy forbids. If it appears: **Analytics & Logs → Web Analytics** → the site → turn automatic setup off (or remove the site).

### 11.4 The AI service is unreachable

**On the VM** (`ssh iltiam`). The network names come from Runbook 5:

```bash
docker network ls --filter name=iltiam- --format '{{.Name}}'
docker network inspect iltiam-staging_edge --format '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'
for h in ai-api ai-worker ai-beat postgres redis; do docker run --rm --network iltiam-staging_edge curlimages/curl:8.22.0 -sS -m 5 -o /dev/null "http://$h:8000/" 2>&1 | tail -1; done
docker run --rm --network iltiam-staging_edge curlimages/curl:8.22.0 -sS -m 5 -o /dev/null -w '%{http_code}\n' \
  -H 'Host: staging-api.iltiamcare.com' -H 'X-Forwarded-Proto: https' http://backend-web:8000/api/health/
docker logs iltiam-staging-cloudflared-1 2>&1 | grep 'Updated to new configuration' | tail -1 | grep -oE 'http://[^\\"]+|http_status:[0-9]+'
```

**What you should see:**
- The networks: `iltiam-staging_edge`, `iltiam-staging_internal` and `iltiam-staging_egress` (and the same three for `iltiam-prod` once production runs).
- On `edge`: only `iltiam-staging-cloudflared-1` and `iltiam-staging-backend-web-1`.
- For each of the five names: `curl: (6) Could not resolve host: <name>`, or `curl: (28) Resolving timed out …`. Both mean the name doesn't exist on the network `cloudflared` uses.
- The backend: a status code (`200`, or `301` or `400`). Any of them proves the network works, so the failures above are real isolation, not a broken test.
- The tunnel's own configuration: exactly `http://web:8080`, `http://backend-web:8000` and `http_status:404` (the catch-all). If the last command prints nothing (the log line was rotated away), check the routes in the dashboard instead: each tunnel still has only its two routes.

**From your laptop** (Git Bash). No public name leads to the AI service, and the AI service's own paths don't exist behind the API hostname:

```bash
for h in ai staging-ai ai-api staging-ai-api; do printf '%-16s ' "$h"; curl -s -m 15 -H 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=$h.iltiamcare.com&type=A" | grep -o '"Answer"' || echo "no Answer"; done
for p in /health /ready /version /capabilities /v1/analyze; do printf '%-14s ' "$p"; curl -s -m 15 -o /dev/null -w '%{http_code}\n' "https://staging-api.iltiamcare.com$p"; done
```

**What you should see:**
- `no Answer` for each name. Cloudflare's DNSSEC answers a name that doesn't exist with `"Status":0` (NOERROR) and no records, not with `"Status":3` (NXDOMAIN), so check for the missing `Answer`, not the status.
- `404` for each path: the backend doesn't have them.

### 11.5 `NUM_PROXIES` resists a fake header

Once `NUM_PROXIES=1` is deployed (section 8). First check the value in GitHub (Git Bash) and in the running container (on the VM):

```bash
gh variable list --env staging -R iltiam/iltiam-deployment | grep -E '^NUM_PROXIES'
sudo -iu deploy /srv/iltiam/repo/scripts/compose.sh staging exec -T backend-web printenv NUM_PROXIES
```

**What you should see:** `NUM_PROXIES  1`, then `1`.

You need two visitors with different public addresses: the VM and your laptop. Open both shells first. If you just ran row 13, wait 70 seconds, so neither limit still counts those requests.

1. **One visitor** (on the VM, or Git Bash on the laptop) sends 25 sign-in attempts at about one per 1.5 seconds, each with a different fake address. The pace keeps them under Cloudflare's own limit (section 7.1), so only the backend's limit (20 a minute per IP) can stop them:

   ```bash
   for i in $(seq 1 25); do curl -s -m 15 -o /dev/null -w '%{http_code} %{content_type}\n' -X POST -H "X-Forwarded-For: 198.51.100.$i" https://staging-api.iltiamcare.com/api/auth/login/; sleep 1.5; done
   ```

   **What you should see:** `400 application/json` (the error for the empty sign-in) about 20 times, then `429 application/json`, the backend's own limit. The fake addresses didn't count as new visitors, so `NUM_PROXIES` is not 2 or more. A `429` that isn't `application/json` comes from Cloudflare (row 13): the pace was too fast. Wait 70 seconds and run it again with `sleep 2`.
2. **The other visitor**, within a minute:

   ```bash
   curl -s -m 15 -o /dev/null -w '%{http_code} %{content_type}\n' -X POST https://staging-api.iltiamcare.com/api/auth/login/
   ```

   **What you should see:** `400 application/json`. A different real visitor isn't limited, so the backend counts real addresses, and `NUM_PROXIES` is not 0 (with 0, every visitor would share the `cloudflared` container's address and its limit).

Sign-in from the first visitor's address stays blocked for up to a minute afterwards; that is normal.

### 11.6 HSTS

Only when all four hostnames serve the real app over HTTPS with no certificate warning:

1. Follow [Runbook 2, section 7](02-cloudflare-dns-tls.md) exactly:
   - **SSL/TLS → Edge Certificates → HTTP Strict Transport Security (HSTS) → Enable HSTS**;
   - Max Age **6 months**, include subdomains **On**, Preload **Off**, No-Sniff **On**;
   - **Save.**

   `grafana.` and `status.` don't exist yet. That is fine: when #10 adds them through Cloudflare, they serve HTTPS from their first minute.
2. The backend sends its own HSTS header (one week by default). Align it to 6 months in both environments:

   ```bash
   gh variable set SECURE_HSTS_SECONDS --env staging --body 15552000 -R iltiam/iltiam-deployment
   gh variable set SECURE_HSTS_SECONDS --env production --body 15552000 -R iltiam/iltiam-deployment
   ```

3. Redeploy both environments ([Runbook 5](05-compose-stack.md), section 6: **Actions → deploy**).
4. Check:

   ```powershell
   curl.exe -sI https://staging-app.iltiamcare.com/ | Select-String "strict-transport-security"
   curl.exe -sI https://staging-api.iltiamcare.com/api/health/ | Select-String "strict-transport-security"
   ```

   **What you should see:** every line says `max-age=15552000; includeSubDomains`. Record it as rows 19 to 21 of Runbook 2's checklist (row 21 is SSL Labs).

## 12. Token rotation, and a leaked token

**Anyone with a tunnel's token can run a connector for that tunnel**, and Cloudflare then sends them part of that environment's traffic, sign-ins included. So treat `CF_TUNNEL_TOKEN` like a password.

**Rotate** (after a staff change, or a leak; [`docs/secrets.md`](../secrets.md), section 2):

1. **Networking → Tunnels →** the tunnel **→ Overview → Refresh token.** Cloudflare refuses **new** connections with the old token from now on. Connectors already running keep working until they restart.
2. Copy the new install command (Docker) and set the secret, as in section 3.2 step 4, with the right `--env`.
3. Redeploy that environment. Its `cloudflared` restarts with the new token. We run one connector per environment, so the hostnames drop for a few seconds during the restart.
4. **What you should see:** the tunnel **Healthy** again, with exactly **one** connector.

**If the token leaked:** do steps 1 to 3 at once. Then open the tunnel's connector list and check that the only connector is ours (its origin IP is the VM's). Any other connector means someone used the token: record it as an incident (DEP-09).

**Never delete a tunnel** to "start fresh": its DNS records and routes point at it, and a new tunnel needs new routes, a new token and a redeploy.

## 13. Verification checklist

The **When** column says when a row can pass:
- **today**: now; rows 6 to 10, 12, 13 and 16 need the temporary test of section 5;
- **after #2**: once Runbook 5 runs the real stack;
- **#35**: once `staging-app` serves the real web app (iltiam/iltiam-web#25), with HSTS after it; tracked in #35;
- **#36**: with production, tracked in #36;
- **after #10**: once the monitoring runbook adds `grafana.`.

The **Verified** column records the date each row last passed.

**Tip:** for HTTP checks, use `curl -sS -o /dev/null -w "HTTP %{http_code}\n" <URL>` (on Windows, `curl.exe` and `-o NUL`). It prints only the status code, so the output you paste never contains the Access sign-in URL (which holds the team name) or cookies. On the King Saud University network, run the checks from another network (section 14).

| # | Check | How | Expected | When | Verified |
|---|---|---|---|---|---|
| 1 | Tunnels | **Networking → Tunnels** | `iltiam-staging` and `iltiam-prod`, both remotely managed (Cloudflared) | today | PASS 2026-10-28: both tunnels created |
| 2 | Tokens in GitHub | `gh secret list --env staging -R iltiam/iltiam-deployment`, and `production` | `CF_TUNNEL_TOKEN` in both | today | PASS 2026-10-28: listed in `staging` and `production` |
| 3 | Routes | each tunnel → **Published application routes** | exactly the two rows of section 4 per tunnel; none to the AI service | today | PASS 2026-10-28: 4 routes (staging 2, prod 2), none to the AI service. The edge-network isolation check stays for after #2 (row 26) |
| 4 | DNS | **DNS → Records**; `Resolve-DnsName` / DoH (section 4) | four proxied CNAMEs; each name has Cloudflare A records; `DNSSEC-validated=True` | today | PASS 2026-10-28: 4 proxied CNAMEs; DoH shows DNSSEC validated for all 4 |
| 5 | Universal certificate | **SSL/TLS → Edge Certificates** | **Active** for `iltiamcare.com, *.iltiamcare.com` (also Runbook 2, row 11) | today | PASS 2026-10-28: Active |
| 6 | Staging tunnel healthy | section 5.1 | 4 `Registered tunnel connection` lines; **Healthy**, 1 connector | today | PASS 2026-10-28: 4 registered connections |
| 7 | Production tunnel healthy | section 5.2 | 4 `Registered tunnel connection` lines; **Healthy**, 1 connector; `app.`/`api.` answer 502 | today | PASS 2026-10-28 (`cloudflared` only): 4 registered connections; `api.iltiamcare.com/api/health/` `502` (no origin). With production's Compose stack: #36 |
| 8 | Staging over HTTPS | `curl.exe -sI https://staging-app.iltiamcare.com/` (section 5.3) | `200`, `server: cloudflare` | today | PASS 2026-10-28: `200` (the stand-in). The real web app: row 22, #35 |
| 9 | Headers at the origin | the two `whoami` commands (section 5.3) | `Host` unchanged; one `X-Forwarded-For` entry, a fake one comes first; `X-Forwarded-Proto: https` | today | PASS 2026-10-28: one `X-Forwarded-For` entry, `X-Forwarded-Proto: https`, `Cf-Connecting-Ip` present; `NUM_PROXIES=1` confirmed. The behaviour check with a spoofed header stays for after #2 (row 27) |
| 10 | API not cached (stand-in) | `1..2 \| % { curl.exe -sI https://staging-api.iltiamcare.com/api/health/ \| Select-String cf-cache-status }` | `DYNAMIC` or `BYPASS`, both times | today | PASS 2026-10-28: `staging-api` `/api/health/` `DYNAMIC` twice; `staging-app` `/` `DYNAMIC` |
| 11 | Cache settings | **Caching → Configuration**; **Cache Rules** | Browser Cache TTL "Respect Existing Headers", Always Online Off; `api-bypass`, `app-bypass-shell`, `app-cache-assets` enabled | today | PASS 2026-10-28 (dashboard): Browser Cache TTL "Respect Existing Headers", Always Online Off, the three Cache Rules active |
| 12 | Custom rules | `curl.exe -s -o NUL -w "%{http_code}" https://staging-app.iltiamcare.com/.env` and `curl.exe -s -o NUL -w "%{http_code}" -X POST https://staging-app.iltiamcare.com/` | `403` and `403` | today | PASS 2026-10-28: `block-scanners` (`/.env`) `403`; `app-read-only` (POST to `staging-app`) `403` |
| 13 | Rate limit | `for i in $(seq 1 20); do curl -s -o /dev/null -w '%{http_code} %{content_type}\n' -X POST https://staging-api.iltiamcare.com/api/auth/login/; done` (Git Bash) | `400 application/json` about ten times (the backend refuses the empty sign-in), then `429` with `text/plain` or `text/html`: Cloudflare's block. Cloudflare counts approximately, so the first `429` may come a few requests later. A `429 application/json` is the backend's own limit: Cloudflare's rule didn't fire | today | PASS 2026-10-31 (Git Bash, King Saud University network): 13 × `400 application/json`, then `429 text/plain` (Cloudflare) |
| 14 | Under Attack rule | **Rules → Configuration Rules** | `under-attack-app` exists and is **off**; `api-no-rewrites` on | today | PASS 2026-10-31 (dashboard): `under-attack-app` off, `api-no-rewrites` on |
| 15 | Access policy | **Access → Policies**; **Login methods**; then, in a private browser window, `https://staging-api.iltiamcare.com/admin/` | `team-only`: Allow, the two emails; One-time PIN available. In the browser, an allowed email gets a code and reaches Django's admin login page; an email not on the list gets none | today | PASS 2026-10-28 (dashboard): One-time PIN listed; `team-only` includes exactly two emails. PASS 2026-10-31 (browser): an allowed email got a code and reached the Django login page; an email not on the list got no code |
| 16 | Access on `/admin` | `curl.exe -s -o NUL -w "%{http_code}" https://staging-api.iltiamcare.com/admin/` and the same for `/admin/login/` and `/api/health/` | `/admin/`: `302` (to the Access sign-in; `401` or `403` also pass), never `200`. `/api/health/` is not redirected to Access (`200` with the real backend; it was `530` before #2). Production: #36. Don't paste the `Location` header: it contains the team name | today | PASS 2026-10-28, `curl` from the OCI VM. `staging-api` and `api`: `/admin/` and `/admin/login/` `302` to Cloudflare Access; `/api/health/` `530` from Cloudflare with no Access redirect (path isolation works; no backend until #2). Still `302` while the tunnel serves (temporary test). PASS 2026-10-31 with the real staging backend (King Saud University network): `/admin/` and `/admin/login/` `302` to Access; `/api/health/` `200` |
| 17 | `grafana` application | **Access → Applications**; after #10 open `https://grafana.iltiamcare.com` in a private window | `grafana` with `team-only`; after #10 the Access page asks for an email, and an address not on the list gets no code | today / after #10 | NOT YET VERIFIED: no `grafana.` DNS until #10 |
| 18 | Test removed | `docker ps -a --filter name=tunnel-test` on the VM; **Tunnels** | no containers; both tunnels **Inactive** | today | PASS 2026-10-28: after teardown both tunnels Inactive/Down |
| 19 | OCI ingress | section 10.1 | TCP 22 and the two ICMP rules only; no NSG with other ingress | today | PASS 2026-10-28: 3 ingress rules, 1 egress rule (all to `0.0.0.0/0`), no NSG on the primary VNIC |
| 20 | VM listens only on 22 | `sudo ss -tlnp`; `docker ps --format '{{.Names}}  {{.Ports}}'` | only `:22` on a public address; no `0.0.0.0:` port mapping | today, again after #2 | PASS 2026-10-28 (today's check): only `sshd` on `:22`; iptables accepts 22 then `REJECT`; no containers. Also during the test: no published container ports, only `sshd` on `:22`. PASS 2026-10-31 with the staging stack: only `sshd` on `:22` publicly (`systemd-resolved` on `127.0.0.53`, local only); iptables accepts 22 then `REJECT`; no published container ports. With production: #36 |
| 21 | Port check from outside | `Test-NetConnection` or Git Bash loop (section 10.4); optional nmap | only `22 True` / `22 open` / `22/tcp open` | today, again after #2 | PASS 2026-10-28 (`Test-NetConnection` loop, Windows PowerShell on the laptop): `22 True`; 80, 443, 111, 3000, 5432, 6379, 8000, 8080, 9090 `False`. 2000 and 7844: not tested (no listener on the VM; `ss` shows only 22). PASS 2026-10-31 with the staging stack (Git Bash loop, King Saud University network): `22 open`; 80, 443, 111, 3000, 5432, 6379, 7844, 8000, 8080, 9090 `closed`; 2000 `open` from the university network itself, not the VM (section 14). With production: #36 |
| 22 | Real app over HTTPS | section 11.1, all four hostnames | API `{"status": "ok"}`; app `200` with `content-security-policy` | after #2 (API); #35 (app); #36 (production) | PASS 2026-10-31, `staging-api` (Runbook 5, row 21): `{"status":"ok"}`, `/api/ready/` ready. The app part: #35. Production: #36 |
| 23 | API never cached | section 11.2 | `DYNAMIC` or `BYPASS` on `api.` and `staging-api.` | after #2; #36 (`api.`) | PASS 2026-10-31, `staging-api`: `cf-cache-status: DYNAMIC`. `api.`: #36 |
| 24 | Assets cached, shell not | section 11.2 | asset `MISS` then `HIT`; `/config.js` `DYNAMIC`/`BYPASS` with `no-cache` | #35 | |
| 25 | No rewriting | section 11.3 | no output (also Runbook 2, row 20) | after #2 (API); #35 (app) | PASS 2026-10-31, `staging-api` `/api/health/`: the backend's JSON unchanged, no injected script (Runbook 2, row 20). The app part: #35 |
| 26 | AI unreachable | section 11.4 | on the VM: only `cloudflared` and `backend-web` on `edge`; `Could not resolve host` or `Resolving timed out` for `ai-api`, `ai-worker`, `ai-beat`, `postgres`, `redis`; the backend answers on the same network; the tunnel's configuration has only the two routes and the 404 catch-all. From outside: no DNS `Answer` for `ai`, `staging-ai`, `ai-api`, `staging-ai-api`; the AI paths give `404` on `staging-api` | after #2; #36 (`iltiam-prod_edge`) | PASS 2026-10-31 (VM; outside checks from the King Saud University network): exactly the three `iltiam-staging_` networks; `edge` holds only `cloudflared` and `backend-web`; the five names `Resolving timed out`; `backend-web` `/api/health/` `200`; tunnel configuration `http://web:8080`, `http://backend-web:8000`, `http_status:404`. `/health`, `/ready`, `/version`, `/capabilities`, `/v1/analyze` `404`; the four names `"Status":0` with no `Answer`. Production: #36 |
| 27 | `NUM_PROXIES` | section 11.5 | `NUM_PROXIES` `1` in GitHub and in the container; `429 application/json` after about 20 attempts despite fake addresses; right after, a different visitor gets `400` | after #2; #36 (production) | PASS 2026-10-31, staging: `1` in GitHub and in `backend-web`. From the VM with a fake `X-Forwarded-For` per request: 20 × `400 application/json`, then `429 application/json` (the backend's limit); right after, the laptop (a different visitor) got `400 application/json`. Production: #36 |
| 28 | HSTS | section 11.6 | `max-age=15552000; includeSubDomains` on app and API (Runbook 2, rows 19 to 21) | #35; #36 (production header) | |

**Record the results as a comment on issue #9:** pass or fail per row, with the date. **Never include** tokens, tunnel IDs, CNAME targets, account or zone IDs, the team name, dashboard URLs, IP addresses or email addresses.

## 14. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `cloudflared` logs `Provided Tunnel token is not valid` or `Unauthorized` | Wrong or cut-off token, or the token was refreshed (section 12). Copy the install command again and repeat section 5.1 step 2; the length check must say `starts eyJ` |
| `TUNNEL_TOKEN is not set in this shell (Runbook 3, section 5)` | The `read` and `export` lines (section 5.1 step 2) weren't run in this SSH session, or `unset` ran before `up` |
| `required variable TUNNEL_TOKEN is missing a value` on `docker compose ps`, `logs` or `down`, after `unset TUNNEL_TOKEN` | The Compose file checks `TUNNEL_TOKEN` for every `docker compose` command, not only `up`. The containers are fine. Use `docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'` and `docker logs tunnel-test-cloudflared-1`, and for teardown `TUNNEL_TOKEN=unused docker compose -f ~/tunnel-test.compose.yml --profile stand-ins down` (section 5.4). Never export the real token again just for these |
| Logs show `failed to dial to edge with quic`, then `protocol=http2` | UDP 7844 is blocked somewhere; `cloudflared` fell back to TCP by itself. Fine |
| Logs show `dial tcp …:7844: i/o timeout` for every connection | Containers can't reach the internet. Test: `docker run --rm curlimages/curl:8.22.0 -sS -m 5 -o /dev/null -w '%{http_code}\n' https://www.cloudflare.com/`. If that also times out: check the OCI egress rule (section 10.1), then `sudo iptables -L FORWARD -n --line-numbers` (Docker's chains must come before Oracle's `REJECT`). Restarting Docker (`sudo systemctl restart docker`) puts its rules back first |
| Browser shows **error 1033** | No connector is running for that tunnel. Expected before Runbook 5 and after the test (section 5.4) |
| **502 Bad Gateway** with the tunnel **Healthy** | `cloudflared` runs but can't reach the service. Expected for production during the connector-only test. Otherwise `docker compose logs cloudflared` shows `Unable to reach the origin service`: wrong service name or port in the route (section 4), the service isn't running, or it isn't on the same network as `cloudflared` |
| Saving a route says a DNS record already exists | Someone added an A or CNAME record by hand (Runbook 2, section 5 says not to). Delete that record in **DNS → Records**, then save the route again |
| `403` on a normal page of the app | `app-read-only` or `block-scanners` matched. **Security → Events** shows which rule and why. Fix the expression; don't delete the rule |
| The mobile app or the web app gets `429` with an HTML page on sign-in | `auth-rate-limit` (section 7.1). **Security → Events** shows it. If it hit real users, raise the request count |
| The rate limit expression is refused | Use the `starts_with` fallback in section 7.1 |
| The Access page appears on API calls, and the mobile app stops working | A `/admin` application was saved without its **path**, so it covers the whole hostname. **Access → Applications →** the app **→ Edit**, add the path `admin` |
| No Access code arrives | Spam folder first. Then check the address is in `team-only` (section 9.2): Access sends nothing to addresses that aren't allowed, and says nothing either |
| `cf-cache-status: HIT` on an API host | A cache rule is wrong. **Caching → Cache Rules**: `api-bypass` must be enabled with the expression in section 6.2. Then **Purge Cache → Custom Purge** for that URL |
| An asset never turns `HIT` | The web image sends `Cache-Control: no-store` or `private` for `/assets/*` (WEB-03), or `app-cache-assets` has a typo |
| `ERR_TOO_MANY_REDIRECTS` (after #2) | The backend doesn't see `X-Forwarded-Proto: https`. Check section 8 (`FORWARDED_ALLOW_IPS` in #2), and that the encryption mode is Full (strict) (Runbook 2, section 6.1) |
| `400 Bad Request` from the backend (after #2) | The hostname is missing from `ALLOWED_HOSTS` ([Runbook 4](04-secrets.md), section 9), or an **HTTP Host Header** was set on the route. Leave it empty (section 4.1) |
| `Test-NetConnection` shows `True` for a port other than 22 | An OCI ingress rule or an NSG allows it (section 10.1), or a Compose file publishes it (`docker ps` shows `0.0.0.0:…`). Remove it and check again |
| Port 2000 shows open from the King Saud University network, but `ss` on the VM shows nothing on it | The university network answers port 2000 itself, for every address: the same test against `1.1.1.1` also shows it open. Not the VM. Count the port as closed if `ss` and the OCI rules agree (section 10), or check it again from another network |
| Tunnel shows **Degraded** | Some of its four connections dropped. Usually network trouble on the VM; `docker compose logs cloudflared`. It recovers by itself |
| HTTPS checks (`curl` or a browser) to `*.iltiamcare.com` fail, or show a certificate not issued for Cloudflare, on the King Saud University network | Cisco Umbrella on the university network intercepts or filters the traffic; Cloudflare is not the cause. Run all verification from another network (a phone hotspot), and write in the results which network was used |

## 15. Security and PDPL notes

- **Tokens:** one per environment, only in the GitHub Environments and, after Runbook 5, in `infra.env` on the VM (`600`). Rotation and leaks: section 12 and [`docs/secrets.md`](../secrets.md).
- **No inbound web traffic:** the VM's only public port is 22. Web traffic arrives through outbound tunnels. Nothing listens on 80 or 443.
- **AI service:** no route and no hostname, and not on the `edge` network.
- **Admin surfaces** (`grafana.`, the backend's `/admin`) are behind Cloudflare Access with an email code for two named people.
- **What Cloudflare must never do:** cache the API, rewrite responses, or inject scripts (sections 6 and 11.3; Runbook 2, section 8).
- **PDPL:** Cloudflare decrypts TLS at its edge, which may be outside the Kingdom. Keeping decryption in the Kingdom needs the paid Data Localization Suite ([ADR-0004](../adr/0004-hosting.md), Decision 4; recorded for DEP#6). Photos, masks and PDFs never pass through Cloudflare (presigned OCI links). Cloudflare Access also processes the two administrators' email addresses.
- **Placeholders only:** this runbook, issues and PRs use the placeholders above, never real values.

## 16. What comes next

- **[Runbook 5](05-compose-stack.md)** (#2): the two Compose projects, each with its `cloudflared` (`TUNNEL_TOKEN` from `CF_TUNNEL_TOKEN`), the `edge`, `internal` and `egress` networks, `FORWARDED_ALLOW_IPS` (section 8) and no `ports:`. Staging runs, and its section 11 checks without the web app passed on 2026-10-31.
- **#35** (after WEB-03, iltiam/iltiam-web#25): rows 22 and 25 for the app hosts, row 24, then HSTS (section 11.6, row 28; Runbook 2, section 7 and rows 19 and 21). WEB-03 itself brings the web image's port (8080, TO CONFIRM), its content security policy and security headers, and its `Cache-Control` headers (section 6.2).
- **#36** (production): section 11 and rows 7, 16, 20 to 28 on `app.` and `api.`.
- **[Runbook 4](04-secrets.md)** (#3): `SECURE_HSTS_SECONDS` (section 11.6) in both Environments, with #35.
- **Runbook 7** (#10): the `grafana.` route (on which tunnel) and `status.`, then row 17; the Access application already exists (section 9.3).
- **DEP-10** (#17): automates the checks of section 11 as the post-deploy smoke test.
- **Later hardening:** SSH through a tunnel with Access, and port 22 closed (section 10.3).
