# model-ad-blocker — project instructions for Claude Code

Network-wide ad blocking + per-device DNS query logging for all devices behind a
Fritz!Box, served by Pi-hole on a Raspberry Pi. This repo is Docker Compose
config, an end-to-end test, and docs — **no custom DNS code**. Pi-hole provides
blocking and per-client query logging out of the box; add code only for things
Pi-hole cannot do.

## Rules

- No Raspberry Pi hardware is available: all validation runs in Docker
  (OrbStack on macOS). The pinned `pihole/pihole` image must stay multi-arch
  (arm64/armv7) so the same compose file runs on the Pi.
- Pi-hole is configured via `FTLCONF_*` env vars in `docker-compose.yml`;
  secrets and host-port overrides live in `.env` (git-ignored, see
  `.env.example`).
- `tests/run-tests.sh` must pass before any commit.
- Update `README.md` when behaviour, commands, or the Fritz!Box/deployment
  steps change.

## Commands

```bash
cp .env.example .env        # once; set PIHOLE_PASSWORD, adjust ports if taken
docker compose up -d --wait # start Pi-hole (web UI http://localhost:8080/admin)
tests/run-tests.sh          # e2e: ad blocked, normal domain resolves, queries logged per client
docker compose down         # stop
```

## Key docs

- `README.md` — architecture, local testing, Raspberry Pi deployment,
  Fritz!Box configuration (local DNS server, IPv6 bypass), privacy note.
