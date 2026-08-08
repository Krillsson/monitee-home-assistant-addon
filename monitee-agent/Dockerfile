ARG BUILD_FROM
ARG RUNTIME_FROM=krillsson/openjdk21-ubuntu-systemd:latest

FROM ${BUILD_FROM} AS agent

# The agent image declares a volume for /var/run/docker.sock, and /var/run is a symlink to
# /run. Docker creates an anonymous volume for it, which lands on the docker.sock the
# Supervisor binds at /run/docker.sock, and the container then refuses to start with
# "not a directory". Copying the application onto the same base image leaves that behind.
FROM ${RUNTIME_FROM}

COPY --from=agent /app /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
RUN chmod a+x /run.sh

WORKDIR /
ENTRYPOINT ["/run.sh"]
