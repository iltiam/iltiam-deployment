# iltiam-deployment

Infrastructure for ILTIAM: hosting decisions, runbooks, environment templates and deployment scripts.

- **Hosting decision:** [ADR-0004](docs/adr/0004-hosting.md) (Oracle Always Free in Riyadh, Cloudflare, one ARM VM).
- **Runbooks:** [`docs/runbooks/`](docs/runbooks/), numbered in the order they are done.
  - [Runbook 1: OCI account and VM](docs/runbooks/01-oci-account-and-vm.md)
  - [Runbook 2: Cloudflare account, DNS, TLS and email records](docs/runbooks/02-cloudflare-dns-tls.md)
  - [Runbook 3: Cloudflare Tunnels, cache and security rules](docs/runbooks/03-cloudflare-tunnels.md)
  - [Runbook 4: secrets and environment files](docs/runbooks/04-secrets.md)
  - [Runbook 5: staging and production as two Compose projects](docs/runbooks/05-compose-stack.md)
- **The stack:** [`compose.yml`](compose.yml) (both environments), image tags in [`env/<env>.versions`](env/),
  deployed by **Actions → deploy** ([`.github/workflows/deploy.yml`](.github/workflows/deploy.yml),
  [`scripts/deploy.sh`](scripts/deploy.sh)). Day to day on the VM: [`scripts/compose.sh`](scripts/compose.sh).
- **Domain check:** [`scripts/check-dns.sh`](scripts/check-dns.sh) checks the DNS, email records and HTTPS headers of `iltiamcare.com` (Runbook 2, section 12).
- **Secrets:** [`docs/secrets.md`](docs/secrets.md) lists every secret, its owner, rotation and revocation. Secrets
  live only in GitHub Environments and on the VM, **never in this repository**: it is public.
- **Environment templates:** [`env/`](env/), names and comments only, no values.
