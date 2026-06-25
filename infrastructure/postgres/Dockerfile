ARG POSTGRES_IMAGE=postgres:18.1-bookworm
FROM ${POSTGRES_IMAGE}

RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-18-repmgr \
    && rm -rf /var/lib/apt/lists/*

COPY infrastructure/postgres/cluster-entrypoint.sh /usr/local/bin/cluster-entrypoint
COPY infrastructure/postgres/init-primary.sh /docker-entrypoint-initdb.d/010-init-primary.sh
COPY infrastructure/postgres/postgresql.conf /etc/postgresql/project-postgresql.conf
COPY infrastructure/postgres/pg_hba.conf /etc/postgresql/project-pg_hba.conf
COPY database /opt/project/database

RUN chmod 0755 \
    /usr/local/bin/cluster-entrypoint \
    /docker-entrypoint-initdb.d/010-init-primary.sh

ENTRYPOINT ["cluster-entrypoint"]
CMD ["postgres"]
