# IP Monitoring

[![CI](https://github.com/NeverovDS/ip_monitoring/actions/workflows/deploy.yml/badge.svg)](https://github.com/NeverovDS/ip_monitoring/actions/workflows/deploy.yml)

Real-time availability monitor for IPv4 hosts. A background worker pings every
host once a minute, records the round-trip time, and streams the results to a
live Hotwire dashboard — no page reloads — alongside a JSON API.

Originally built with **Roda**; migrated to **Rails 8 + Hotwire** and deployed
to **AWS** with Kamal. The original Roda version is preserved at the
[`v1.0-roda`](https://github.com/NeverovDS/ip_monitoring/releases/tag/v1.0-roda) tag.

> A live instance runs on AWS — URL and demo credentials available on request.

## Highlights

- **Live dashboard** — per-row RTT updates are pushed over WebSocket (Turbo
  Streams + Action Cable) straight from the background worker.
- **Concurrent checks** — a thread-pooled ICMP pinger probes every host in
  parallel each minute (Sidekiq + sidekiq-cron).
- **Rich statistics** — average / min / max / median / std-dev RTT and packet
  loss, computed in a single SQL aggregate; latency chart via Stimulus + Chart.js.
- **Status history** — enable/disable events are recorded by a PostgreSQL
  trigger (the schema is tracked as `structure.sql`).
- **JSON API** — versioned under `/api/v1`, HTTP Basic auth.
- **Production deployment on AWS** — one-command zero-downtime deploys with
  Kamal; CI/CD via GitHub Actions.

## Architecture

```
Developer / GitHub Actions ──build & push──▶ Amazon ECR (private image registry)
                                                   │ pull
                                                   ▼
                                    EC2 (Graviton / arm64, Ubuntu, Kamal)
                                    ├─ web   — Puma (Thruster) behind kamal-proxy :80
                                    ├─ job   — Sidekiq worker (pings every minute)
                                    └─ redis — Action Cable + Sidekiq broker
                                                   │
                                                   ▼
                                    Amazon RDS — managed PostgreSQL (private subnet)
```

**CI/CD:** a push to `main` triggers GitHub Actions, which builds the arm64
image natively, authenticates to AWS via **OIDC** (no long-lived keys), pushes
to ECR, and runs `kamal deploy`. The test suite runs on every push and PR.

## Tech stack

| Area | Choice |
|------|--------|
| Language / framework | Ruby 3.4, Rails 8 |
| Frontend | Hotwire (Turbo + Stimulus), Chart.js, importmap |
| Database | PostgreSQL (SQL schema + trigger), Active Record |
| Background jobs | Sidekiq + sidekiq-cron, Redis |
| Web server | Puma + Thruster |
| Deployment | Docker, Kamal 2, AWS (EC2 · RDS · ECR), GitHub Actions (OIDC) |

## Local development

Requires Ruby 3.4.2 and Docker.

```sh
docker compose up -d   # Postgres (5433) + Redis
bin/setup              # install gems, prepare the database
bin/rails server       # http://localhost:3000
bundle exec sidekiq    # run the background checks
```

Run the test suite:

```sh
bin/rails test
```

## API

All endpoints require HTTP Basic auth. In development the base URL is
`http://localhost:3000`.

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/ips` | List monitored IPs |
| `POST` | `/api/v1/ips` | Add an IP — `{ "ip_address": "8.8.8.8", "enabled": true }` |
| `GET` | `/api/v1/ips/:id` | Show one IP |
| `DELETE` | `/api/v1/ips/:id` | Remove an IP |
| `POST` | `/api/v1/ips/:id/enable` | Resume monitoring |
| `POST` | `/api/v1/ips/:id/disable` | Pause monitoring |
| `GET` | `/api/v1/ips/:id/stats` | RTT stats over `time_from` / `time_to` (default: last hour) |

```sh
curl -u admin:secret http://localhost:3000/api/v1/ips
```

The Sidekiq dashboard is available at `/sidekiq` (same Basic auth).

## Implementation notes

- **IPv4 only.** Reserved, loopback, link-local (including the cloud metadata
  endpoint) and RFC1918 private ranges are rejected; IPv6 input is refused
  explicitly rather than silently mishandled.
- **ICMP inside a container.** The image installs `iputils-ping` and grants the
  binary `cap_net_raw`, so the non-root application user can send pings without
  running the container as root.
- **Schema as SQL.** A database trigger maintains the status-change history, so
  the schema is tracked as `db/structure.sql` rather than `schema.rb`.
