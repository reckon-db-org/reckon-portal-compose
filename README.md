# reckon-portal-compose

Docker Compose deployment for **reckon-portal** on a single VM (currently `reckon-db.org`, 159.69.210.171).

Scope: one Phoenix umbrella + Caddy in front. The product site has **no database** — it is stateless apart from the event-sourced blog, which ReckonDB persists to a volume. Multi-node reckon-db cluster work lives elsewhere (eventually a refresh of `reckon-internal/deploy/`).

## Services

| Service | Port (host) | Description |
|---|---|---|
| `caddy` | 80, 443 | Reverse proxy + auto-HTTPS via HTTP-01 |
| `reckon-portal` | — | Phoenix release (`beamcampus/reckon-portal:latest`) on container port 4000 |
| `watchtower` | — | Pulls labeled containers on a 5-min poll |

## First-time setup

On the target VM (`ssh root@reckon-db.org`):

```bash
# 1. Install Docker
curl -fsSL https://get.docker.com | sh

# 2. Clone this repo
git clone https://codeberg.org/reckon-internal/reckon-portal-compose
cd reckon-portal-compose

# 3. Configure
cp .env.example .env
# edit .env — at minimum:
#   SECRET_KEY_BASE          (mix phx.gen.secret OR openssl rand -base64 64)
#   RECKON_MAILGUN_API_KEY   (for the contact form)
#   RECKON_MAILGUN_DOMAIN

# 4. Bring it up
./scripts/deploy.sh init
```

DNS prerequisite: `reckon-db.org` A record points at the VM. Caddy will provision a Let's Encrypt cert via HTTP-01 on first request to `:80`.

## Day-to-day

```bash
./scripts/deploy.sh status     # what's running
./scripts/deploy.sh logs       # tail everything
./scripts/deploy.sh logs caddy # tail one service
./scripts/deploy.sh update     # pull latest image, recreate
./scripts/deploy.sh shell      # /bin/sh inside the portal container
```

`watchtower` polls Docker Hub for `beamcampus/reckon-portal:latest` every 5 minutes and recreates the container when the digest changes. The CI workflow in `reckon-portal/.github/workflows/docker.yml` pushes `:latest` on every merge to main — so merge to main = production update within ~5 min.

## Required env vars

See `.env.example`. The compose file errors out at `up` time if `SECRET_KEY_BASE`, `RECKON_MAILGUN_API_KEY` or `RECKON_MAILGUN_DOMAIN` are missing — no silent fallbacks.

## DNS + domains

Caddy serves the apex `reckon-db.org` and 301s `www.reckon-db.org` → apex. To add subdomains:
1. Add an A/AAAA record for the subdomain
2. Add a Caddyfile block — see `caddy/Caddyfile` for the template

## Mailgun

Shares the **same Mailgun account** as `macula-realm-compose`. Wire-up:
1. Copy the API key value from macula-realm's `.env` (`MACULA_MAILGUN_API_KEY`) into `RECKON_MAILGUN_API_KEY` here.
2. Add a Mailgun-verified sending domain `mg.reckon-db.org` (DNS records via the Mailgun dashboard).

That's it — `reckon-portal/system/config/runtime.exs` reads these env vars and `raise`s if `RECKON_MAILGUN_API_KEY` or `RECKON_MAILGUN_DOMAIN` is missing. The compose file matches that contract with `:?` defaults so missing values fail at `up` time, not deep in a release crash log.

## What's NOT here

- Multi-node / clustered reckon-db (different concern, lives in `reckon-internal/deploy/` eventually)
- Backups (TODO — the only state is the `blog_store_data` volume / event-sourced blog; snapshot it off-VM on a cron)
- Metrics (TODO — Prometheus scrape endpoint exists in the portal at `/metrics`, no exporter wired)
- Cluster config (the old `reckon_site_deploy/.env.example` had `CLUSTER_*` vars for multi-node — single-VM doesn't need them; reintroduce when scaling)
