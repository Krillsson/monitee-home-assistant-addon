#!/usr/bin/env bash
set -euo pipefail

readonly OPTIONS_FILE=/data/options.json
readonly CONFIG_DIR=/config
readonly CONFIG_FILE="${CONFIG_DIR}/configuration.yml"
readonly SUPERVISOR_API=http://supervisor

log() {
    printf '[monitee-agent] %s\n' "$*"
}

# JSON strings are also valid YAML double quoted scalars, so this escapes
# anything a user can type into an option
yaml_string() {
    jq -n --arg value "$1" '$value'
}

option() {
    jq -r --arg key "$1" --arg fallback "${2-}" \
        'if has($key) and .[$key] != null and .[$key] != "" then (.[$key] | tostring) else $fallback end' \
        "${OPTIONS_FILE}"
}

supervisor_get() {
    if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
        return 1
    fi
    curl -fsS -m 10 -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" "${SUPERVISOR_API}/$1"
}

json_field() {
    printf '%s' "$1" | jq -r "$2 // empty" 2>/dev/null || true
}

tcp_reachable() {
    timeout 2 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null
}

write_os_release() {
    local pretty="$1" name version
    if [[ "${pretty}" =~ ^(.*[^[:space:]])[[:space:]]+([0-9][0-9A-Za-z.+~-]*)$ ]]; then
        name="${BASH_REMATCH[1]}"
        version="${BASH_REMATCH[2]}"
    else
        name="${pretty}"
        version=""
    fi

    {
        printf 'NAME="%s"\n' "${name}"
        printf 'PRETTY_NAME="%s"\n' "${pretty}"
        printf 'ID=%s\n' "$(printf '%s' "${name}" | tr 'A-Z ' 'a-z-')"
        if [ -n "${version}" ]; then
            printf 'VERSION="%s"\n' "${version}"
            printf 'VERSION_ID="%s"\n' "${version}"
        fi
    } >/etc/os-release
}

if [ ! -f "${OPTIONS_FILE}" ]; then
    log "No options file at ${OPTIONS_FILE}, giving up"
    exit 1
fi

mkdir -p "${CONFIG_DIR}"

# The container runs in the host's network namespace but keeps its own hostname
# and /etc/os-release, so the machine would otherwise report itself as the
# add-on's own container. Ask the Supervisor what it actually is.
host_hostname=""
host_os=""
if host_info="$(supervisor_get host/info)"; then
    host_hostname="$(json_field "${host_info}" '.data.hostname')"
    host_os="$(json_field "${host_info}" '.data.operating_system')"
fi

if [ -n "${host_os}" ]; then
    write_os_release "${host_os}"
    log "Running on ${host_os}"
fi

# an empty serverName would be used as the name, so leave the whole block out
# instead and let the agent fall back to the hostname on its own
server_name="$(option server_name "${host_hostname}")"
notifications_block=""
if [ -n "${server_name}" ]; then
    notifications_block="notifications:
  serverName: $(yaml_string "${server_name}")"
fi

docker_enabled=true
docker_host=""
if [ -S /run/docker.sock ]; then
    docker_host="unix:///run/docker.sock"
elif [ -S /var/run/docker.sock ]; then
    docker_host="unix:///var/run/docker.sock"
else
    docker_enabled=false
    log "No Docker socket, containers will not be listed. Turn off Protection mode to grant access"
fi

docker_host_line=""
if [ -n "${docker_host}" ]; then
    docker_host_line="
  host: $(yaml_string "${docker_host}")"
fi

mqtt_enabled=false
mqtt_url=""
mqtt_username=""
mqtt_password=""
mqtt_mode="$(option mqtt auto)"

case "${mqtt_mode}" in
    manual)
        mqtt_url="$(option mqtt_url)"
        mqtt_username="$(option mqtt_username)"
        mqtt_password="$(option mqtt_password)"
        if [ -z "${mqtt_url}" ]; then
            log "MQTT is set to manual but mqtt_url is empty, skipping MQTT"
        else
            mqtt_enabled=true
        fi
        ;;
    auto)
        if mqtt_service="$(supervisor_get services/mqtt)"; then
            broker_host="$(json_field "${mqtt_service}" '.data.host')"
            broker_port="$(json_field "${mqtt_service}" '.data.port')"
            broker_ssl="$(json_field "${mqtt_service}" '.data.ssl')"
            mqtt_username="$(json_field "${mqtt_service}" '.data.username')"
            mqtt_password="$(json_field "${mqtt_service}" '.data.password')"

            if [ -n "${broker_host}" ] && [ -n "${broker_port}" ]; then
                # On the host network the broker's container name does not
                # resolve, but a broker add-on publishes its port on the host
                if ! tcp_reachable "${broker_host}" "${broker_port}"; then
                    if tcp_reachable 127.0.0.1 "${broker_port}"; then
                        log "${broker_host} does not resolve here, using 127.0.0.1 instead"
                        broker_host=127.0.0.1
                    fi
                fi

                if [ "${broker_ssl}" = "true" ]; then
                    mqtt_url="ssl://${broker_host}:${broker_port}"
                else
                    mqtt_url="tcp://${broker_host}:${broker_port}"
                fi
                mqtt_enabled=true
            fi
        fi

        if [ "${mqtt_enabled}" = "false" ]; then
            log "No MQTT broker configured in Home Assistant, skipping MQTT"
        fi
        ;;
esac

generate=true
if [ "$(option custom_configuration false)" = "true" ]; then
    if [ -f "${CONFIG_FILE}" ]; then
        generate=false
        log "Using your own configuration.yml, add-on options are ignored"
    else
        log "There is no configuration.yml yet, writing one to start from"
    fi
fi

if [ "${generate}" = "true" ]; then
    ups_host="$(option ups_host localhost)"

    cat >"${CONFIG_FILE}" <<EOF
# Written by the Monitee agent add-on on every start from the options in the
# Configuration tab. Turn on "Custom configuration" there to edit it yourself.
user:
  username: $(yaml_string "$(option username monitee)")
  password: $(yaml_string "$(option password)")
metricsConfig:
  monitor:
    interval: 45
    unit: SECONDS
  history:
    interval: 30
    unit: MINUTES
    purging:
      olderThan: 14
      unit: DAYS
      purgeEvery: 1
      purgeEveryUnit: DAYS
processes:
  enabled: true
windows:
  enableOhmJniWrapper: false
linux:
  # the host's systemd and journal are not reachable from an add-on
  systemDaemonServiceManagement:
    enabled: false
  journalLogs:
    enabled: false
docker:
  enabled: ${docker_enabled}${docker_host_line}
  hideContainerNetworks: true
  updateCheck:
    # Home Assistant updates its own containers
    enabled: false
ups:
  enabled: $(option ups false)
  host: $(yaml_string "${ups_host}")
  port: 3493
connectivityCheck:
  enabled: true
  address: https://ifconfig.me
internetServicesCheck:
  enabled: true
  services:
    - address: google.com
      name: Google
      port: 80
    - address: one.one.one.one
      name: Cloudflare
      port: 80
updateCheck:
  enabled: true
  address: https://api.github.com
  user: krillsson
  repo: monitee-agent
${notifications_block}
mqtt:
  enabled: ${mqtt_enabled}
  url: $(yaml_string "${mqtt_url}")
  username: $(yaml_string "${mqtt_username}")
  password: $(yaml_string "${mqtt_password}")
  containers: $(option mqtt_containers false)
  networkInterfaces: $(option mqtt_network_interfaces true)
  homeAssistant:
    enabled: true
mDNS:
  enabled: true
upnp:
  enabled: false
forwardHttpToHttps: false
selfSignedCertificates:
  enabled: true
  populateCN: true
  populateSAN: true
formatting:
  temperatureUnit: system
EOF

    if [ "${mqtt_enabled}" = "true" ]; then
        log "Publishing to ${mqtt_url}"
    fi
fi

LOGGING_LEVEL_ROOT="$(option log_level info | tr '[:lower:]' '[:upper:]')"
export LOGGING_LEVEL_ROOT

cd /
exec java \
    -server \
    -Djava.awt.headless=true \
    -XX:+UseG1GC \
    -XX:MinHeapFreeRatio=2 \
    -XX:MaxHeapFreeRatio=10 \
    -XX:+AlwaysPreTouch \
    -Xmx512m \
    -Xms128m \
    -cp @/app/jib-classpath-file \
    "$(cat /app/jib-main-class-file)"
