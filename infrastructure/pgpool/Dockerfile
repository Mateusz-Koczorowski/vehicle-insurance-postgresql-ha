ARG POSTGRES_IMAGE=postgres:18.1-bookworm
FROM ${POSTGRES_IMAGE}

RUN apt-get update \
    && apt-get install -y --no-install-recommends pgpool2 \
    && rm -rf /var/lib/apt/lists/*

COPY infrastructure/pgpool/pgpool.conf /etc/pgpool2/pgpool.conf.template
COPY infrastructure/pgpool/pool_hba.conf /etc/pgpool2/pool_hba.conf
COPY infrastructure/pgpool/entrypoint.sh /usr/local/bin/pgpool-entrypoint

RUN chmod 0755 /usr/local/bin/pgpool-entrypoint \
    && mkdir -p /var/run/postgresql /var/log/pgpool \
    && chown -R postgres:postgres /var/run/postgresql /var/log/pgpool /etc/pgpool2

USER postgres
ENTRYPOINT ["pgpool-entrypoint"]
