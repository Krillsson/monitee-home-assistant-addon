# Monitee Home Assistant add-on

Home Assistant add-on repository for [monitee-agent](https://github.com/Krillsson/monitee-agent),
the server monitoring backend for the [Monitee](https://monitee.app) Android app.

Add this repository under *Settings → Apps → Install app*, three dots in the top right,
*Repositories*:

```
https://github.com/Krillsson/monitee-home-assistant-addon
```

Then install **Monitee agent** from the list.

## Monitee agent

Measures the machine Home Assistant runs on — CPU, memory, disks and SMART, file systems,
network, sensors, GPUs and containers — and serves it over a GraphQL API on port 8443 for the
app to connect to.

It also publishes everything to MQTT and announces it to Home Assistant, so the machine turns
up as a device with sensors on its own. With the Mosquitto broker add-on installed there is
nothing to configure: the add-on asks Home Assistant which broker to use.

Requires amd64 or aarch64, and Protection mode turned off to read the host's disks, processes
and containers. See [the add-on documentation](monitee-agent/DOCS.md).

## Issues

Report them at [Krillsson/monitee-agent](https://github.com/Krillsson/monitee-agent/issues).
