#!/bin/sh
# Translates Runsite env vars into n8n settings, waits for Postgres, starts n8n.
set -eu

export DB_WAIT_TIMEOUT="${DB_WAIT_TIMEOUT:-180}"

if [ -z "${N8N_ENCRYPTION_KEY:-}" ]; then
    echo "FATAL: N8N_ENCRYPTION_KEY is not set. Without a fixed key every redeploy" >&2
    echo "would generate a new one and make saved credentials unreadable." >&2
    exit 1
fi

# The platform injects PORT when the user overrides the service port.
if [ -n "${PORT:-}" ]; then
    export N8N_PORT="$PORT"
fi

# Split DATABASE_URL into the DB_POSTGRESDB_* variables n8n expects.
# Node does the parsing so URL-encoded passwords are decoded correctly.
database_url_part() {
    node -e '
        const url = new URL(process.env.DATABASE_URL.replace(/^postgres:\/\//, "postgresql://"));
        const parts = {
            host: url.hostname,
            port: url.port || "5432",
            database: decodeURIComponent(url.pathname.replace(/^\//, "")),
            user: decodeURIComponent(url.username),
            password: decodeURIComponent(url.password),
            sslmode: url.searchParams.get("sslmode") || "",
        };
        process.stdout.write(parts[process.argv[1]]);
    ' "$1"
}

if [ -n "${DATABASE_URL:-}" ] && [ -z "${DB_POSTGRESDB_HOST:-}" ]; then
    export DB_TYPE=postgresdb
    DB_POSTGRESDB_HOST="$(database_url_part host)"
    DB_POSTGRESDB_PORT="$(database_url_part port)"
    DB_POSTGRESDB_DATABASE="$(database_url_part database)"
    DB_POSTGRESDB_USER="$(database_url_part user)"
    DB_POSTGRESDB_PASSWORD="$(database_url_part password)"
    export DB_POSTGRESDB_HOST DB_POSTGRESDB_PORT DB_POSTGRESDB_DATABASE DB_POSTGRESDB_USER DB_POSTGRESDB_PASSWORD
    case "$(database_url_part sslmode)" in
        require|verify-ca|verify-full) export DB_POSTGRESDB_SSL_ENABLED=true ;;
    esac
fi

# PUBLIC_URL is the service's public https URL from the platform. n8n wants
# it with a trailing slash, and host/protocol/editor URL must match it so
# webhook and OAuth callback links point at the real domain, not localhost.
public_url="${PUBLIC_URL:-${N8N_WEBHOOK_URL:-${WEBHOOK_URL:-}}}"
unset WEBHOOK_URL
if [ -n "$public_url" ]; then
    case "$public_url" in
        */) ;;
        *) public_url="$public_url/" ;;
    esac
    export N8N_WEBHOOK_URL="$public_url"
    export N8N_EDITOR_BASE_URL="${N8N_EDITOR_BASE_URL:-$public_url}"
    without_scheme="${public_url#*://}"
    export N8N_HOST="${N8N_HOST:-${without_scheme%%/*}}"
    export N8N_PROTOCOL="${N8N_PROTOCOL:-${public_url%%://*}}"
fi

# Postgres is a separate service and may still be booting on first deploy.
if [ "${DB_TYPE:-}" = "postgresdb" ]; then
    echo "Waiting for Postgres at ${DB_POSTGRESDB_HOST}:${DB_POSTGRESDB_PORT:-5432}..."
    node -e '
        const net = require("net");
        const host = process.env.DB_POSTGRESDB_HOST;
        const port = Number(process.env.DB_POSTGRESDB_PORT || 5432);
        const deadline = Date.now() + Number(process.env.DB_WAIT_TIMEOUT) * 1000;
        const tryConnect = () => {
            const socket = net.connect({ host, port, timeout: 3000 });
            socket.once("connect", () => { socket.destroy(); process.exit(0); });
            const retry = () => {
                socket.destroy();
                if (Date.now() > deadline) {
                    console.error("FATAL: Postgres is not reachable");
                    process.exit(1);
                }
                setTimeout(tryConnect, 2000);
            };
            socket.once("error", retry);
            socket.once("timeout", retry);
        };
        tryConnect();
    '
fi

exec /docker-entrypoint.sh "$@"
