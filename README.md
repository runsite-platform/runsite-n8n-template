# n8n on Runsite

A one-click template that runs your own [n8n](https://n8n.io) instance on Runsite. n8n is a visual workflow
editor with 400+ integrations: webhooks, schedules, Telegram, Google Sheets, HTTP requests, databases and AI
models. This repository is a thin wrapper around the official `n8nio/n8n` image that connects it to a Runsite
PostgreSQL database and the service's public URL.

[![Deploy on Runsite](https://img.shields.io/badge/Deploy%20on-Runsite-0f172a?style=for-the-badge)](https://dashboard.runsite.app/templates)

Deploying from the [Runsite template gallery](https://dashboard.runsite.app/templates) creates the web service and
a PostgreSQL database and wires every environment variable. Open the service URL, create the owner account and
start building workflows. Workflows, credentials and execution history live in PostgreSQL, so the service needs
no disk.

- Runsite: https://runsite.app
- Dashboard: https://dashboard.runsite.app
- Docs: https://docs.runsite.app
- Template gallery: https://dashboard.runsite.app/templates
- n8n docs: https://docs.n8n.io

## What's inside

- **`Dockerfile`:** the official `n8nio/n8n` image pinned to a release (`N8N_VERSION`), with defaults for running
  behind the Runsite ingress (`N8N_PROXY_HOPS=1`, port 5678, `Europe/Kyiv` time zone, telemetry off).
- **`deploy/entrypoint.sh`:** runs before n8n starts. It splits `DATABASE_URL` into the `DB_POSTGRESDB_*`
  variables n8n expects (URL-encoded passwords are decoded), sets the webhook and editor URLs from `PUBLIC_URL`,
  waits for PostgreSQL and refuses to start without `N8N_ENCRYPTION_KEY`.
- **`docker-compose.yml`:** a local copy of the Runsite setup: PostgreSQL and the n8n image.
- **`runsite-template.json`:** the template definition used in the Runsite template catalog.

## Deploy on Runsite

1. Click **Deploy on Runsite** above (or open n8n in the [template gallery](https://dashboard.runsite.app/templates))
   and sign in.
2. Pick a project name and repository name, then click **Deploy**. Runsite copies this repository into your
   GitHub account, creates the web service and the database and starts the first build.
3. Choose a plan with at least 1 GB of memory that does not sleep. n8n uses 400 to 600 MB when idle, and a
   sleeping service misses schedule triggers and polling nodes.
4. When the build finishes, open the web service URL. n8n asks you to create the owner account on the first
   visit; there is no default password.

What the template sets for you:

| Variable | Value |
|---|---|
| `DATABASE_URL` | Internal URL of the new PostgreSQL database |
| `N8N_ENCRYPTION_KEY` | 48 random characters, generated once at deploy |
| `PUBLIC_URL` | Public URL of the web service |
| `GENERIC_TIMEZONE` | `Europe/Kyiv`, the default time zone for schedule triggers |

Anything else from the [n8n environment variables](https://docs.n8n.io/hosting/configuration/environment-variables/)
can be added in the [Runsite dashboard](https://dashboard.runsite.app): web service → **Environment**. Saving
redeploys the service.

## The encryption key

n8n encrypts every saved credential (API keys, OAuth tokens, passwords) with `N8N_ENCRYPTION_KEY`. If the key
changes, n8n can no longer read the credentials and they have to be entered again.

- Never change or delete `N8N_ENCRYPTION_KEY` after the first start.
- Copy it somewhere safe. You need it to restore a database backup into a new service.
- Moving to another service: set the same `N8N_ENCRYPTION_KEY` there before the first start.

The entrypoint stops with an error when the key is missing, instead of letting n8n generate a key that would be
lost on the next redeploy.

## Webhooks

Production webhook URLs look like `{PUBLIC_URL}/webhook/<path>`, test URLs like `{PUBLIC_URL}/webhook-test/<path>`.
The entrypoint passes `PUBLIC_URL` to n8n as `N8N_WEBHOOK_URL` and `N8N_EDITOR_BASE_URL`, so the editor shows
links on your domain instead of `localhost`, and OAuth callbacks (Google, Slack and others) use the same domain.

After you attach a custom domain, set `PUBLIC_URL` to it, for example `https://automations.example.com`.

## Configuration

Variables read by `deploy/entrypoint.sh`:

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | empty | PostgreSQL connection. Split into `DB_POSTGRESDB_*` unless `DB_POSTGRESDB_HOST` is already set. `sslmode=require` turns on TLS. |
| `N8N_ENCRYPTION_KEY` | required | Encrypts saved credentials. See [The encryption key](#the-encryption-key). |
| `PUBLIC_URL` | empty | Public URL of the service. Sets `N8N_WEBHOOK_URL`, `N8N_EDITOR_BASE_URL`, `N8N_HOST` and `N8N_PROTOCOL`. |
| `PORT` | empty | Overrides `N8N_PORT` when the service port is changed. |
| `DB_WAIT_TIMEOUT` | `180` | Seconds to wait for PostgreSQL before giving up. |

Defaults set in the `Dockerfile`, each can be overridden in the environment:

| Variable | Default | Purpose |
|---|---|---|
| `N8N_PORT` | `5678` | Port n8n listens on. |
| `N8N_PROXY_HOPS` | `1` | n8n runs behind one proxy (the Runsite ingress). |
| `GENERIC_TIMEZONE`, `TZ` | `Europe/Kyiv` | Time zone for schedule triggers and dates. |
| `N8N_DIAGNOSTICS_ENABLED` | `false` | Usage telemetry to n8n. |
| `N8N_VERSION_NOTIFICATIONS_ENABLED` | `false` | Update notices in the editor. |
| `N8N_RUNNERS_TASK_TIMEOUT` | `300` | Seconds a Code node may run. |
| `N8N_UNVERIFIED_PACKAGES_ENABLED` | `true` | Installing community nodes that n8n has not verified. |
| `N8N_COMPRESSION_NODE_MAX_DECOMPRESSED_SIZE_BYTES` | `268435456` | Largest archive (256 MB) the Compression node unpacks. |
| `N8N_COMPRESSION_NODE_MAX_ZIP_ENTRIES` | `1000` | Most files the Compression node unpacks from one archive. |

## Updating n8n

The n8n version is pinned in the `Dockerfile`:

```dockerfile
ARG N8N_VERSION=2.44.6
```

Change it to a newer release from the [n8n release notes](https://docs.n8n.io/release-notes/), commit and push.
Runsite rebuilds the service and n8n migrates the database on start. Take a database backup first: migrations
are not reversed when you go back to an older version.

## Local development

Requirements: Docker.

```bash
docker compose up --build
```

Open http://localhost:5678 and create the owner account. The compose file starts PostgreSQL with a password that
contains `@`, `:`, `/` and `#`, so it also checks that URL-encoded passwords are decoded. `docker compose down -v`
stops the containers and deletes the data.

## Limitations

- **Python in the Code node:** the official image has no Python, so the Code node runs JavaScript only.
- **Single instance:** this template runs n8n in regular mode, without queue mode workers or Redis.
- **Sleeping plans:** schedule triggers and polling nodes do not fire while the service sleeps.

## License

The files in this repository are MIT licensed. See `LICENSE`.

n8n itself is fair-code software by n8n GmbH, distributed under the
[Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md). It allows running n8n for your
own internal business purposes. Read the license before offering n8n to others as a hosted service.
