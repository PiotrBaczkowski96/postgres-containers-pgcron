ARG BASE=debian:trixie-slim@sha256:9b6ccd28f4913155f35e10ecd4437347d86ebce4ecf5853b3568141468faec56
FROM $BASE AS minimal
ARG PG_VERSION
ARG PG_MAJOR
ENV PATH=$PATH:/usr/lib/postgresql/$PG_MAJOR/bin
RUN apt-get update && \
    apt-get install -y --no-install-recommends postgresql-common ca-certificates gnupg && \
    /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y -c "${PG_MAJOR}" && \
    apt-get install -y --no-install-recommends -o Dpkg::::="--force-confdef" -o Dpkg::::="--force-confold" postgresql-common && \
    sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf && \
    apt-get install -y --no-install-recommends \
      libsasl2-modules libldap-common \
      -o Dpkg::::="--force-confdef" -o Dpkg::::="--force-confold" "postgresql-${PG_MAJOR}=${PG_VERSION}*" && \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
    rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/*
RUN usermod -u 26 postgres
USER 26

FROM minimal AS standard
ARG EXTENSIONS
ARG STANDARD_ADDITIONAL_POSTGRES_PACKAGES
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends locales-all ${STANDARD_ADDITIONAL_POSTGRES_PACKAGES} ${EXTENSIONS} \
      postgresql-${PG_MAJOR}-cron && \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
    rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/*
USER 26

FROM standard AS system
ARG BARMAN_VERSION
ENV PIP_BREAK_SYSTEM_PACKAGES=1
USER root
RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		build-essential python3-dev \
		python3-pip \
		python3-psycopg2 \
		python3-setuptools \
	&& \
	pip3 install --no-cache-dir barman[cloud,azure,snappy,google,zstandard,lz4]==${BARMAN_VERSION} && \
	python3 -c "import sysconfig, compileall; compileall.compile_dir(sysconfig.get_path('stdlib'), quiet=1); compileall.compile_dir(sysconfig.get_path('purelib'), quiet=1); compileall.compile_dir(sysconfig.get_path('platlib'), quiet=1)" && \
	apt-get remove -y --purge --autoremove build-essential python3-dev && \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
	rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/*
USER 26
```

The only change is adding `postgresql-${PG_MAJOR}-cron` in the `standard` stage.

You'll also need to configure PostgreSQL to load and target your database. Add these to your `postgresql.conf`:
```
shared_preload_libraries = 'pg_cron'
cron.database_name = 'api_prod'
