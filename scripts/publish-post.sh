#!/bin/sh
# Publish a markdown post (with YAML frontmatter) into the LIVE event-sourced
# blog on reckon-db.org, through the CMD command boundary
# (GuideBlogPostLifecycle.publish_post) on the running release node.
#
# Frontmatter fields used: title, slug, excerpt. The body is everything after
# the frontmatter, minus a leading H1 (the post page renders the title itself).
# Fields are base64-transported to avoid any shell/Elixir quoting issues.
#
# Usage: publish-post.sh path/to/post.md ["Author Name"]
set -eu

MD="${1:?usage: publish-post.sh <post.md> [author]}"
AUTHOR="${2:-}"
HOST="${PUBLISH_HOST:-root@reckon-db.org}"
KEY="${PUBLISH_KEY:-$HOME/.ssh/id_hetzner}"
[ -f "$MD" ] || { echo "no such file: $MD" >&2; exit 1; }

fm() { awk 'f&&/^---/{exit} f{print} /^---/{f=1}' "$MD"; }
val() { fm | grep -m1 "^$1:" | sed "s/^$1:[[:space:]]*//; s/^\"//; s/\"\$//"; }

TITLE=$(val title); SLUG=$(val slug); EXCERPT=$(val excerpt)
[ -n "$SLUG" ] || { echo "missing slug in frontmatter" >&2; exit 1; }
BODY=$(awk 'p{print} /^---/{c++; if(c==2)p=1}' "$MD" | sed '0,/^# /{/^# /d}')

b64() { printf %s "$1" | base64 | tr -d '\n'; }

EXPR="GuideBlogPostLifecycle.publish_post(%{slug: \"$SLUG\", title: Base.decode64!(\"$(b64 "$TITLE")\"), excerpt: Base.decode64!(\"$(b64 "$EXCERPT")\"), body: Base.decode64!(\"$(b64 "$BODY")\"), author: Base.decode64!(\"$(b64 "$AUTHOR")\")}) |> IO.inspect(label: :published)"

echo ">>> publishing '$TITLE' (slug: $SLUG) to $HOST"
printf %s "$EXPR" | ssh -i "$KEY" -o ConnectTimeout=20 "$HOST" \
  'cat > /tmp/publish.expr && docker exec -i reckon-portal /app/bin/reckon_portal rpc "$(cat /tmp/publish.expr)"; rm -f /tmp/publish.expr'
