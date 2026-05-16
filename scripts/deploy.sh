#!/usr/bin/env bash
#
# Deployment helper for reckon-portal on reckon-db.org.
#
# Usage: ./scripts/deploy.sh [command]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${SCRIPT_DIR}/.."
COMPOSE="docker compose -f ${COMPOSE_DIR}/docker-compose.yml"

usage() {
    cat <<EOF
reckon-portal deploy helper

Usage: $0 [command]

Commands:
  init      First-time setup: pull images, start, let Caddy provision TLS.
  up        Start all services.
  down      Stop all services.
  restart   Stop + start.
  update    Pull latest images, force-recreate, then migrate.
  migrate   Run database migrations against the running container.
  deploy    Full deploy: pull → up → migrate.
  logs [s]  Tail logs (optionally for a single service).
  status    docker compose ps.
  shell     Open shell in the reckon-portal container.
  remote    Run shell in the postgres container.
EOF
}

require_env() {
    if [ ! -f "${COMPOSE_DIR}/.env" ]; then
        echo "ERROR: .env not found at ${COMPOSE_DIR}/.env" >&2
        echo "Copy .env.example to .env and fill in the required values." >&2
        exit 1
    fi
}

cmd_init() {
    require_env
    echo "==> Pulling images"
    $COMPOSE pull
    echo "==> Starting services (Caddy will provision TLS on first request)"
    $COMPOSE up -d
    echo "==> Initialization complete. Watch certs at: $0 logs caddy"
}

cmd_up() {
    require_env
    $COMPOSE up -d
}

cmd_down() {
    $COMPOSE down
}

cmd_restart() {
    cmd_down
    cmd_up
}

cmd_update() {
    require_env
    echo "==> Pulling latest images"
    $COMPOSE pull
    echo "==> Recreating containers"
    $COMPOSE up -d --force-recreate
    echo "==> Running migrations"
    cmd_migrate
}

cmd_migrate() {
    require_env
    $COMPOSE exec -T reckon-portal /app/bin/migrate
}

cmd_deploy() {
    require_env
    echo "==> Step 1/3: pull"
    $COMPOSE pull
    echo "==> Step 2/3: up"
    $COMPOSE up -d
    echo "==> Step 3/3: migrate"
    cmd_migrate
    echo "==> Deploy complete"
}

cmd_logs() {
    if [ $# -gt 0 ]; then
        $COMPOSE logs -f --tail=200 "$@"
    else
        $COMPOSE logs -f --tail=200
    fi
}

cmd_status() {
    $COMPOSE ps
}

cmd_shell() {
    $COMPOSE exec reckon-portal /bin/sh
}

cmd_remote() {
    $COMPOSE exec postgres psql -U "${POSTGRES_USER:-reckon_portal}" "${POSTGRES_DB:-reckon_portal_prod}"
}

case "${1:-}" in
    init)    shift; cmd_init "$@";;
    up)      shift; cmd_up "$@";;
    down)    shift; cmd_down "$@";;
    restart) shift; cmd_restart "$@";;
    update)  shift; cmd_update "$@";;
    migrate) shift; cmd_migrate "$@";;
    deploy)  shift; cmd_deploy "$@";;
    logs)    shift; cmd_logs "$@";;
    status)  shift; cmd_status "$@";;
    shell)   shift; cmd_shell "$@";;
    remote)  shift; cmd_remote "$@";;
    -h|--help|help|"") usage;;
    *)
        echo "Unknown command: $1" >&2
        usage
        exit 2
        ;;
esac
