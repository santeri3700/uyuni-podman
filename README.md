# uyuni-podman

An alternative way to set up and run an Uyuni Server all-in-one container with just Podman 4.5+ and Podman Compose. No [uyuni-tools](https://github.com/uyuni-project/uyuni-tools/) required.

# Disclaimer
This project is not affiliated or endorsed by the [Uyuni Project](https://www.uyuni-project.org). \
Image upgrades are not guaranteed to work and your data may or may not be persistent. \
**Use at your own risk!**

# Uyuni Server

## Initial configuration
- Make a copy of the [compose.uyuni-server-example.yaml](compose.uyuni-server-example.yaml) and change it to fit your environment.
- Do not unset any of the variables already defined in the example. They are the bare minimum.
- Ensure container hostname and UYUNI_FQDN are actually resolvable by the container host.
- Custom certificate can be provided with volume mounts and environment variables "CA_CERT", "SERVER_CERT" and "SERVER_KEY". \
  Alternatively, [install-cert.sh](install-cert.sh) can be used to install a new certificate after first time setup.

## Running
- `sudo podman compose -f compose.uyuni-server.yaml up -d`
- `sudo podman exec -it uyuni-server bash`
**NOTE**: First time setup takes around 3-5 minutes on [recommended hardware](https://www.uyuni-project.org/uyuni-docs/en/uyuni/installation-and-upgrade/hardware-requirements.html).

## Viewing first time setup logs and results
- `sudo podman exec uyuni-server systemctl status uyuni-server-first-time-setup.service`
- `sudo podman exec uyuni-server journalctl -f -u uyuni-server-first-time-setup.service`
- `sudo podman exec uyuni-server cat /var/log/susemanager_setup.log`

## Upgrades
Uyuni Server upgrades can be done by re-building a new image and/or changing the image from the compose file.

However, upgrades without the [uyuni-tools](https://github.com/uyuni-project/uyuni-tools/) may be unreliable or fail if the upgrade requires new volume mounts or additional commands to be executed within the container.

PostgreSQL version migrations must be done manually. The Uyuni Project probably provides a separate container image to do this.

- Check current Uyuni version: `sudo podman inspect --format '{{ index .Config.Labels "org.uyuni.version" }}' uyuni-server`
- Check image Uyuni version: `sudo podman image inspect --format '{{ index .Config.Labels "org.uyuni.version" }}' registry.opensuse.org/uyuni/server:latest`
- Check current PostgreSQL version: `sudo podman exec uyuni-server cat /var/lib/pgsql/data/PG_VERSION`
- Check image PostgreSQL version: `sudo podman run --rm -it registry.opensuse.org/uyuni/server:latest rpm -qa --qf '%{VERSION}\\n' 'name=postgresql[0-8][0-9]-server' | cut -d. -f1 | sort -n | tail -1`

# Uyuni Proxy
TBD

# License
This project (uyuni-podman) is licensed under the terms of the MIT license. See more in [LICENSE](LICENSE).
