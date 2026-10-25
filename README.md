# model-ad-blocker

Network-wide ad blocking and per-device DNS query logging for every device behind a
Fritz!Box, served by [Pi-hole](https://pi-hole.net/) running on a Raspberry Pi.

There is no custom DNS code in this repo: Pi-hole already blocks ads (DNS sinkhole
with the default blocklist) and logs every query per client device (FTL database,
browsable in the web UI under *Query Log*). This repo contains only the Docker
Compose configuration, an end-to-end test, and deployment docs.

```
devices ──DNS──▶ Raspberry Pi (Pi-hole) ──allowed queries──▶ upstream DNS
   ▲                      │
   └── Fritz!Box DHCP     └── blocked ad domains → 0.0.0.0, everything logged per device
       announces the Pi as DNS server
```

## Local development and tests (no Raspberry Pi needed)

Requires Docker (OrbStack/Docker Desktop on macOS).

```bash
cp .env.example .env        # set PIHOLE_PASSWORD; adjust ports if 53/8080 are taken
docker compose up -d --wait # start Pi-hole
tests/run-tests.sh          # end-to-end: blocking, resolution, per-client logging
docker compose down         # stop
```

Web UI: `http://localhost:8080/admin` (or your `PIHOLE_WEB_PORT`). Log in with
`PIHOLE_PASSWORD` and open **Query Log** to see queries per client.

## Deploying to a Raspberry Pi

The image `pihole/pihole:2026.10.0` is multi-arch (arm64/armv7) — the same compose
file runs unchanged on the Pi. *(Not yet verified on real hardware.)*

1. Flash Raspberry Pi OS Lite (64-bit), boot, SSH in.
2. Install Docker: `curl -fsSL https://get.docker.com | sh` and re-login.
3. `git clone <this repo> && cd model-ad-blocker && cp .env.example .env`
   — set a real `PIHOLE_PASSWORD`; keep `PIHOLE_DNS_PORT=53`.
4. `docker compose up -d --wait`
5. Verify from another machine: `nslookup doubleclick.net <pi-ip>` → `0.0.0.0`.

## Fritz!Box configuration

Goal: every device gets the Pi as its DNS server via DHCP, so Pi-hole sees (and
logs) each device individually.

1. **Give the Pi a fixed IP**: *Heimnetz → Netzwerk →* edit the Pi's entry →
   enable *"Diesem Netzwerkgerät immer die gleiche IPv4-Adresse zuweisen"*.
2. **Announce the Pi as local DNS server**: *Heimnetz → Netzwerk →
   Netzwerkeinstellungen → weitere Einstellungen → IPv4-Einstellungen →
   Lokaler DNS-Server* = the Pi's IP.
3. **Close the IPv6 bypass**: under *IPv6-Einstellungen*, set the local
   *DNSv6-Server* to the Pi's IPv6 address (give the Pi a static ULA first) —
   otherwise devices resolve over IPv6 and skip Pi-hole entirely.
4. Devices pick up the new DNS on their next DHCP renew — reconnect Wi-Fi or
   reboot devices to apply immediately.

Do **not** use *Internet → Zugangsdaten → DNS-Server* for this: that only changes
the router's own upstream, so every query would reach Pi-hole as a single client
(the Fritz!Box) and per-device logs would be lost.

## Privacy note

Pi-hole logs the DNS history of every device in the household. Inform the people
using the network; as operator you are responsible for complying with applicable
privacy law (GDPR/KVKK). Retention is configurable in the Pi-hole web UI
(*Settings → Database*, default ~91 days).
