# syntax=docker/dockerfile:1
#
# n8n for Runsite: the upstream image plus an entrypoint that maps the
# platform's DATABASE_URL and public URL onto n8n's own settings.

ARG N8N_VERSION=2.44.6
FROM n8nio/n8n:${N8N_VERSION}

COPY --chmod=0755 deploy/entrypoint.sh /runsite-entrypoint.sh

ENV N8N_PORT=5678 \
    N8N_PROXY_HOPS=1 \
    GENERIC_TIMEZONE=Europe/Kyiv \
    TZ=Europe/Kyiv \
    N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
    N8N_DIAGNOSTICS_ENABLED=false \
    N8N_VERSION_NOTIFICATIONS_ENABLED=false \
    N8N_RUNNERS_TASK_TIMEOUT=300 \
    N8N_UNVERIFIED_PACKAGES_ENABLED=true \
    N8N_COMPRESSION_NODE_MAX_DECOMPRESSED_SIZE_BYTES=268435456 \
    N8N_COMPRESSION_NODE_MAX_ZIP_ENTRIES=1000

EXPOSE 5678

USER node

ENTRYPOINT ["tini", "--", "/runsite-entrypoint.sh"]
