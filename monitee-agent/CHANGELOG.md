# Changelog

The first three numbers are the version of the agent this wraps. A fourth is a change to the
add-on itself.

## 0.42.0.1

- Fix: the add-on would not start with Protection mode turned off. The agent image declares a
  volume for `/var/run/docker.sock`, which is a symlink to the `/run/docker.sock` the Supervisor
  binds, and Docker refused to mount one over the other. The application is now copied onto the
  same base image without that declaration
- Say so in the log when Home Assistant cannot be asked which broker to use, rather than
  reporting that no broker is configured

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
