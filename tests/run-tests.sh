#!/usr/bin/env bash
# End-to-end test against the Docker stack:
#   1. an ad domain is blocked (0.0.0.0)
#   2. a normal domain still resolves
#   3. both queries are logged with client identity in the FTL database
set -euo pipefail
cd "$(dirname "$0")/.."

BLOCKED_DOMAIN=doubleclick.net
ALLOWED_DOMAIN=example.com

[ -f .env ] || { echo "ERROR: .env missing — run: cp .env.example .env"; exit 1; }

echo "==> starting pihole (waits for healthy)"
docker compose up -d --wait pihole

lookup() { docker compose run --rm dns-client nslookup "$1" pihole 2>&1; }

echo "==> 1/3 ad domain is blocked: $BLOCKED_DOMAIN"
# first boot downloads the default blocklist (gravity); retry up to 60s
for i in $(seq 1 12); do
  out=$(lookup "$BLOCKED_DOMAIN") || true
  if echo "$out" | grep -qw '0\.0\.0\.0'; then break; fi
  if [ "$i" = 12 ]; then echo "FAIL: not blocked:"; echo "$out"; exit 1; fi
  sleep 5
done
echo "    OK"

echo "==> 2/3 normal domain resolves: $ALLOWED_DOMAIN"
out=$(lookup "$ALLOWED_DOMAIN") || { echo "FAIL: lookup error:"; echo "$out"; exit 1; }
if echo "$out" | grep -qw '0\.0\.0\.0'; then echo "FAIL: allowed domain blocked:"; echo "$out"; exit 1; fi
echo "$out" | grep -q 'Name:' || { echo "FAIL: no answer:"; echo "$out"; exit 1; }
echo "    OK"

echo "==> 3/3 queries are logged with client identity"
ftl_count() {
  docker compose exec -T pihole pihole-FTL sqlite3 /etc/pihole/pihole-FTL.db \
    "SELECT count(*) FROM queries WHERE domain IN ('$BLOCKED_DOMAIN','$ALLOWED_DOMAIN') AND client != '';"
}
# shortcut: FTL flushes queries to disk every 60s, so poll up to 90s; upgrade if tests must be fast
for i in $(seq 1 18); do
  n=$(ftl_count) || n=0
  if [ "${n:-0}" -ge 2 ]; then break; fi
  if [ "$i" = 18 ]; then echo "FAIL: queries not in log db (count=${n:-0})"; exit 1; fi
  sleep 5
done
docker compose exec -T pihole pihole-FTL sqlite3 /etc/pihole/pihole-FTL.db \
  "SELECT datetime(timestamp,'unixepoch') AS time, client, domain, status FROM queries WHERE domain IN ('$BLOCKED_DOMAIN','$ALLOWED_DOMAIN') ORDER BY id DESC LIMIT 5;"
echo "    OK"

echo "ALL TESTS PASSED"
