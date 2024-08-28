# Uyuni Server container
ARG UYUNI_SERVER_IMAGE=registry.opensuse.org/uyuni/server
ARG UYUNI_SERVER_TAG=latest
FROM ${UYUNI_SERVER_IMAGE}:${UYUNI_SERVER_TAG}

# Add first time setup script and service
COPY --chown=root:root uyuni-server-first-time-setup.sh /usr/local/sbin/uyuni-server-first-time-setup.sh
RUN chmod +x /usr/local/sbin/uyuni-server-first-time-setup.sh
COPY uyuni-server-first-time-setup.service /etc/systemd/system/uyuni-server-first-time-setup.service
RUN systemctl enable uyuni-server-first-time-setup.service
