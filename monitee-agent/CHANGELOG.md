# Changelog

## 0.42.0

First release. Wraps monitee-agent 0.42.0.

- Writes `configuration.yml` from the add-on options on every start, or leaves it alone with
  **Custom configuration** turned on
- Picks up the broker from Home Assistant's MQTT service, so the machine turns up as a device
  without any configuration
- Takes the hostname and the operating system from the Supervisor, so it reports the machine
  Home Assistant runs on rather than the container
- Turns off what an add-on cannot reach on Home Assistant OS: the host's systemd, the journal
  and the container image update check
