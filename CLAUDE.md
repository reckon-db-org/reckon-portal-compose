# CLAUDE.md — reckon-portal-compose

Single-VM Docker Compose deployment for **reckon-portal** on `reckon-db.org` (Hetzner, 159.69.210.171).

## What this is

Mirror of the `macula-realm-compose` pattern, scoped to one Phoenix umbrella behind Caddy + Postgres.

This is **not** the place for multi-node reckon-db cluster deployment. That work belongs in a refresh of `reckon-internal/deploy/` (which is currently ExESDB-shaped and stale — separate cleanup pass needed).

## Production access

```bash
ssh -i ~/.ssh/id_hetzner root@reckon-db.org
```

Check `.ssh/config` for a tidied alias; the key is unencrypted but the host requires it.

## Layout

| Path | What |
|---|---|
| `docker-compose.yml` | Service definitions |
| `caddy/Caddyfile` | Reverse proxy + HTTPS config (HTTP-01, single domain) |
| `scripts/deploy.sh` | Operator CLI (init / up / down / update / migrate / logs / shell) |
| `.env.example` | Required env vars; copy to `.env` before deploying |

## CI flow

`reckon-portal/.github/workflows/docker.yml` pushes `beamcampus/reckon-portal:{latest,version}` to Docker Hub on merge to main. `watchtower` on the VM polls every 5 min and recreates the labeled container when the `:latest` digest changes. End-to-end lag merge-to-prod ≈ 5–10 min after the image build completes.

## Image source

Docker Hub: `beamcampus/reckon-portal`. **Not** ghcr.io. If we ever switch publishers, change `image:` in `docker-compose.yml` AND the `docker.yml` workflow in `reckon-portal/`.

## Phoenix release shape

`/app/bin/{start,server,migrate}` overlays. `start` is the entrypoint and runs migrate-then-server. Use `./scripts/deploy.sh migrate` for manual migrations against the running container.

## DNS

`reckon-db.org` and `www.reckon-db.org` point at the VM. To add subdomains:
1. Add DNS record
2. Add a block to `caddy/Caddyfile`
3. `./scripts/deploy.sh restart` (Caddy reloads the file on container restart)

## Gotchas

- **`PHX_HOST` must match the Caddy host.** Mismatches break Phoenix URL generation.
- **The Phoenix release boots before postgres is migrated.** `init` brings everything up, then run `migrate` separately. Subsequent `update` does pull → recreate → migrate automatically.
- **No backups configured yet** — TODO. The single-VM Postgres holds all state.
