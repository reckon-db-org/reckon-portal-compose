#!/bin/sh
# Local container smoke for the event-sourced blog store.
#
# Builds the reckon-portal image and verifies the two things local `mix test`
# cannot: that embedded ReckonDB boots as the unprivileged `nobody` user on a
# freshly-mounted named volume (the volume-permission trick), and that a post
# round-trips CMD -> PRJ -> QRY inside the container.
#
# No Postgres required: the eval starts ONLY the blog apps, never the portal
# Repo, so nothing touches the database.
set -eu

PORTAL_DIR="${PORTAL_DIR:-$HOME/work/codeberg.org/reckon-internal/reckon-portal/system}"
IMAGE="reckon-portal:smoke"
VOL="blog_smoke_vol"

echo ">>> building image from $PORTAL_DIR/Dockerfile"
docker build -f "$PORTAL_DIR/Dockerfile" -t "$IMAGE" "$PORTAL_DIR"

docker volume rm "$VOL" >/dev/null 2>&1 || true

echo ">>> running blog-store smoke (user=nobody, fresh volume, no Postgres)"
docker run --rm -v "$VOL:/data/blog_store" \
  -e BLOG_STORE_DATA_DIR=/data/blog_store \
  -e RECKON_PORTAL_DATABASE_URL=ecto://u:p@nohost/db \
  -e SECRET_KEY_BASE=0000000000000000000000000000000000000000000000000000000000000000000000 \
  -e RECKON_MAILGUN_API_KEY=dummy -e RECKON_MAILGUN_DOMAIN=dummy \
  "$IMAGE" bin/reckon_portal eval '
    {:ok, _} = Application.ensure_all_started(:project_blog_posts)
    {:ok, _} = Application.ensure_all_started(:guide_blog_post_lifecycle)
    {:ok, _} = Application.ensure_all_started(:query_blog_posts)
    slug = "container-smoke"
    {:ok, _, _} = GuideBlogPostLifecycle.publish_post(%{slug: slug, title: "Container Smoke", body: "it works", excerpt: "", author: "ci"})
    Process.sleep(1000)
    case QueryBlogPosts.get_by_slug(slug) do
      {:ok, %{title: "Container Smoke"}} -> IO.puts(">>> SMOKE_OK")
      other -> IO.puts(">>> SMOKE_FAIL: #{inspect(other)}"); System.halt(1)
    end
  '

docker volume rm "$VOL" >/dev/null 2>&1 || true
echo ">>> smoke done (SMOKE_OK above = blog store boots as nobody on a fresh volume)"
