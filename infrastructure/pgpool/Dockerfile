ARG POSTGRES_IMAGE=postgres:18.1-bookworm
ARG PGPOOL_VERSION=4.7.2-1.pgdg12+1
FROM ${POSTGRES_IMAGE}
ARG PGPOOL_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends pgpool2=${PGPOOL_VERSION} \
    && rm -rf /var/lib/apt/lists/*

COPY infrastructure/pgpool/pgpool.conf /etc/pgpool2/pgpool.conf.template
COPY infrastructure/pgpool/pool_hba.conf /etc/pgpool2/pool_hba.conf
COPY infrastructure/pgpool/entrypoint.sh /usr/local/bin/pgpool-entrypoint

RUN chmod 0755 /usr/local/bin/pgpool-entrypoint \
    && mkdir -p /var/run/postgresql /var/log/pgpool \
    && chown -R postgres:postgres /var/run/postgresql /var/log/pgpool /etc/pgpool2

USER postgres
ENTRYPOINT ["pgpool-entrypoint"]
