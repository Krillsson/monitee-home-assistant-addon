# Monitee agent

Runs the [Monitee agent](https://github.com/Krillsson/monitee-agent) on the machine Home
Assistant runs on. It measures the hardware and the operating system — CPU, memory, disks,
file systems, network, GPUs, containers — and serves it over a GraphQL API that the
[Monitee](https://play.google.com/store/apps/details?id=com.krillsson.monitee) Android app
connects to.

It also publishes everything to MQTT and announces it to Home Assistant, so the machine turns
up under *Settings → Devices & services → MQTT* as a device with sensors, with no configuration
beyond starting the add-on.

## Getting started

1. Set a **password** under *Configuration*. There is no default, and the add-on will not start
   without one.
2. Turn off **Protection mode** under *Info*. Without it the agent cannot read the host's
   processes, its disks or its containers — see below for what each one costs.
3. Start it.

If you have the Mosquitto broker add-on installed, that is all. Within a minute the machine
appears as a device with around forty sensors on it. If your broker is somewhere else, set
**MQTT** to `manual` and fill in the url.

To use the app, point it at the Home Assistant machine's address on port **8443**, with the
username and password from *Configuration*. The certificate is self-signed, which the app
handles. [Connection guide](https://github.com/Krillsson/monitee-agent/blob/master/docs/connect-app-to-server.md).

## Protection mode

Home Assistant protects add-ons from the host by default. The agent's whole job is to look at
the host, so with protection on it reports much less:

| Turned off, you get | With protection on |
|---|---|
| The host's processes | Only the agent's own process |
| Disk temperature and SMART health | Nothing about physical disks |
| Containers, their logs and their stats | No containers at all |

The rest — CPU, memory, file systems, network, sensors, GPUs — works either way.

## Configuration

Everything under *Configuration* is written into a `configuration.yml` each time the add-on
starts. The options cover what most installs need:

- **Username** and **password** are what the app signs in with.
- **Server name** is what the machine is called in the app and in Home Assistant. Left empty it
  uses the hostname Home Assistant knows itself by.
- **MQTT** on `auto` asks Home Assistant for the broker it already uses, credentials included.
  `manual` takes the url, username and password below it. `off` publishes nothing, and the
  machine will only be reachable through the app.
- **A sensor per container** and **sensors per network interface** decide how much of a busy
  server ends up in Home Assistant. See
  [the MQTT documentation](https://github.com/Krillsson/monitee-agent/blob/master/docs/home-assistant.md)
  for what is published.
- **UPS** reads a UPS over NUT, from the machine named in **UPS host**.

### Beyond the options

The agent has [a good deal more configuration](https://github.com/Krillsson/monitee-agent/blob/master/config/configuration.yml)
than fits here — monitor intervals, history retention, ntfy and webhook notifications, log
readers, a custom CPU temperature sensor. Turn on **Custom configuration** to reach it.

The add-on then leaves `configuration.yml` alone and every option above is ignored. The file
lives in `/addon_configs/xxxxxxxx_monitee-agent/`, reachable with the File editor, Studio Code
Server or Samba add-ons, and the one written on the last start is a working starting point.
Restart the add-on after editing.

## What it cannot do here

- **The host's services and journal.** Home Assistant OS keeps systemd to itself, so service
  management and journal logs are turned off. Container logs work.
- **Updating itself.** The agent is updated by updating this add-on, so the update notifications
  it can send are pointed at the app, not at the container.
- **Container image updates.** Home Assistant manages its own containers, so the check is off.

## Troubleshooting

**It will not start.** The password is empty. Home Assistant also refuses passwords that have
turned up in a breach, which it says in the log.

**No device in Home Assistant.** The add-on log says which broker it publishes to on the line
starting with *Publishing to*. If it says *No MQTT broker configured*, Home Assistant has no
broker to point it at — install the Mosquitto broker add-on or set MQTT to `manual`.

**Disks show no temperature.** Protection mode is on, or the disk does not report one.

**Containers are missing.** Protection mode is on.
