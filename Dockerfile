FROM debian:buster

ENV DEBIAN_FRONTEND noninteractive
ENV TZ=Asia/Shanghai
ENV PG_MAJOR 12



# explicitly set user/group IDs
RUN set -eux; \
	groupadd -r postgres --gid=999; \
# https://salsa.debian.org/postgresql/postgresql-common/blob/997d842ee744687d99a2b2d95c1083a2615c79e8/debian/postgresql-common.postinst#L32-35
	useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
# also create the postgres user's home directory with appropriate permissions
# see https://github.com/docker-library/postgres/issues/274
	mkdir -p /var/lib/postgresql; \
	chown -R postgres:postgres /var/lib/postgresql


RUN \
sed -i "s#deb.debian.org#mirrors.huaweicloud.com#g" /etc/apt/sources.list && \
sed -i "s#security.debian.org#mirrors.huaweicloud.com#g" /etc/apt/sources.list && \
apt-get clean && \
apt-get update && \
apt-get -y upgrade && \
apt-get install --no-install-recommends -y -q vim curl wget git gnupg2 ca-certificates psmisc procps rpm xz-utils sudo --fix-missing


RUN echo "deb http://nginx.org/packages/debian buster nginx" > /etc/apt/sources.list.d/nginx.list \
&& curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add - \
&& apt update \
&& apt install nginx=1.18.0-1~buster -y


RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
&& curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
&& apt update \
&& apt install postgresql-$PG_MAJOR -y


COPY --from=redis:5.0.8-buster /usr/local/bin/redis-benchmark /usr/local/bin/redis-benchmark
COPY --from=redis:5.0.8-buster /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=redis:5.0.8-buster /usr/local/bin/redis-cli /usr/local/bin/redis-cli

RUN mkdir -p /var/lib/redis && mkdir -p /harbor/ && mkdir -p /var/log/jobs && mkdir -p /portal && mkdir -p /storage && mkdir -p /chart_storage && mkdir -p /var/lib/trivy/.cache/trivy && mkdir -p /var/lib/trivy/.cache/reports

ENV PATH $PATH:/usr/lib/postgresql/$PG_MAJOR/bin
ENV PGDATA /var/lib/postgresql/data

COPY --from=postgres:12 /usr/local/bin/gosu /usr/local/bin/gosu
COPY --from=goharbor/chartmuseum-photon:v2.0.0 /home/chart/chartm /usr/local/bin/chartm
COPY --from=goharbor/clair-adapter-photon:v2.0.0 /clair-adapter/clair-adapter /usr/local/bin/clair-adapter
COPY --from=goharbor/clair-photon:v2.0.0 /home/clair/clair /usr/local/bin/clair
COPY --from=goharbor/harbor-core:v2.0.0 /harbor/harbor_core /usr/local/bin/harbor_core
COPY --from=goharbor/harbor-core:v2.0.0 /harbor/migrations /harbor/migrations
COPY --from=goharbor/harbor-core:v2.0.0 /harbor/views /harbor/views
COPY --from=goharbor/harbor-jobservice:v2.0.0 /harbor/harbor_jobservice /usr/local/bin/harbor_jobservice
COPY --from=goharbor/notary-server-photon:v2.0.0 /bin/migrate-patch /usr/local/bin/migrate-patch
COPY --from=goharbor/notary-server-photon:v2.0.0 /bin/migrate /usr/local/bin/migrate
COPY --from=goharbor/notary-server-photon:v2.0.0 /bin/notary-server /usr/local/bin/notary-server
COPY --from=goharbor/notary-signer-photon:v2.0.0 /bin/notary-signer /usr/local/bin/notary-signer
COPY --from=goharbor/notary-server-photon:v2.0.0 /migrations /migrations

COPY --from=goharbor/harbor-portal:v2.0.0 /usr/share/nginx/html /portal
COPY --from=goharbor/registry-photon:v2.0.0 /usr/bin/registry_DO_NOT_USE_GC /usr/local/bin/registry
COPY --from=goharbor/harbor-registryctl:v2.0.0  /home/harbor/harbor_registryctl /usr/local/bin/harbor_registryctl

COPY --from=goharbor/trivy-adapter-photon:v2.0.0 /usr/local/bin/trivy /usr/local/bin/trivy
COPY --from=goharbor/trivy-adapter-photon:v2.0.0 /home/scanner/bin/scanner-trivy /usr/local/bin/scanner-trivy


RUN curl --fail --silent -L https://github.com/just-containers/s6-overlay/releases/download/v2.0.0.1/s6-overlay-amd64.tar.gz | tar -xzvf - -C /


RUN curl -sfSLk https://raw.githubusercontent.com/antirez/redis/5.0/redis.conf \
|grep -v -e '^\s*#' -e '^\s*$' \
|sed -e 's@bind 127.0.0.1@bind 0.0.0.0@' \
|sed -e "s@protected-mode yes@protected-mode no@" \
|sed -e "s@dir ./@dir /var/lib/redis@" \
|sed -e "s@appendonly no@appendonly yes@" > /etc/redis.conf





# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN set -eux; \
	if [ -f /etc/dpkg/dpkg.cfg.d/docker ]; then \
# if this file exists, we're likely in "debian:xxx-slim", and locales are thus being excluded so we need to remove that exclusion (since we need locales)
		grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
		sed -ri '/\/usr\/share\/locale/d' /etc/dpkg/dpkg.cfg.d/docker; \
		! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
	fi; \
	apt-get update; apt-get install -y --no-install-recommends locales; rm -rf /var/lib/apt/lists/*; \
	localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8


RUN set -eux; \
for i in "cfssl" "cfssl-bundle" "cfssl-certinfo" "cfssl-newkey" "cfssl-scan" "cfssljson" "mkbundle" "multirootca"; do \
curl --retry 10 -sSL -o /usr/local/bin/${i} https://github.com/cloudflare/cfssl/releases/download/v1.4.1/${i}_1.4.1_linux_amd64; \
chmod +x /usr/local/bin/${i}; \
done

RUN curl --retry 10 -sSL -o /wait-for-it.sh https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh && chmod +x /wait-for-it.sh


RUN set -eux; \
apt-get update; \
apt-get install -y --no-install-recommends \
# install "nss_wrapper" in case we need to fake "/etc/passwd" and "/etc/group" (especially for OpenShift)
# https://github.com/docker-library/postgres/issues/359
# https://cwrap.org/nss_wrapper.html
libnss-wrapper \
# install "xz-utils" for .sql.xz docker-entrypoint-initdb.d files
xz-utils jq \
; \
rm -rf /var/lib/apt/lists/*


ENV PATH $PATH:/usr/lib/postgresql/$PG_MAJOR/bin

ADD ./wait-for-postgres.sh /
ADD ./init-cert.sh /
ADD ./init-database.sh /
ADD ./etc /etc/
ADD ./services /etc/services.d/
ADD ./s6-service /usr/bin/
RUN chmod +x /usr/bin/s6-service

ENTRYPOINT ["/init"]


