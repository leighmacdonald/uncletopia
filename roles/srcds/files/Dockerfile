FROM debian:bullseye-slim
LABEL maintainer="leigh.macdonald@gmail.com"

ARG PUID=1000

ENV USER steam
ENV HOMEDIR "/home/${USER}"
ENV STEAMCMDDIR "${HOMEDIR}/steamcmd"
ENV STEAMAPPID 232250
ENV STEAMAPP tf
ENV STEAMAPPDIR "${HOMEDIR}/${STEAMAPP}-dedicated"
ENV METAMOD_VERSION 1.11
ENV SOURCEMOD_VERSION 1.11

RUN set -x \
	# Install, update & upgrade packages \
    && dpkg --add-architecture i386 \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
        wget=1.21-1+deb11u1 \
        ca-certificates=20210119 \
        lib32z1=1:1.2.11.dfsg-2+deb11u1 \
        libncurses5:i386=6.2+20201114-2 \
        libbz2-1.0:i386=1.0.8-4 \
        libtinfo5:i386=6.2+20201114-2 \
        libcurl3-gnutls:i386=7.74.0-1.3+deb11u1 \
		lib32stdc++6=10.2.1-6 \
		lib32gcc-s1=10.2.1-6 \
		wget=1.21-1+deb11u1 \
		ca-certificates=20210119 \
		nano=5.4-2 \
		curl=7.74.0-1.3+deb11u1 \
		locales=2.31-13+deb11u3 \
	&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& dpkg-reconfigure --frontend=noninteractive locales \
	# Create unprivileged user
	&& useradd -u "${PUID}" -m "${USER}" \
	# Download SteamCMD, execute as user
	&& su "${USER}" -c \
		"mkdir -p \"${STEAMCMDDIR}\" \
		&& wget -qO- 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' | tar xvzf - -C \"${STEAMCMDDIR}\" \
		&& \"./${STEAMCMDDIR}/steamcmd.sh\" +quit \
		&& mkdir -p \"${HOMEDIR}/.steam/sdk32\" \
		&& ln -s \"${STEAMCMDDIR}/linux32/steamclient.so\" \"${HOMEDIR}/.steam/sdk32/steamclient.so\" \
		&& ln -s \"${STEAMCMDDIR}/linux32/steamcmd\" \"${STEAMCMDDIR}/linux32/steam\" \
		&& ln -s \"${STEAMCMDDIR}/steamcmd.sh\" \"${STEAMCMDDIR}/steam.sh\"" \
	# Symlink steamclient.so; So misconfigured dedicated servers can find it
	&& ln -s "${STEAMCMDDIR}/linux64/steamclient.so" "/usr/lib/x86_64-linux-gnu/steamclient.so" \
	# Clean up
	&& apt-get remove --purge --auto-remove -y \
		wget \
	&& rm -rf /var/lib/apt/lists/* \


# Switch to user
USER ${USER}

WORKDIR ${STEAMCMDDIR}

# To generate run: make sourcemod
COPY ut-sourcemod.tar.gz entry.sh /

RUN set -x \
	&& mkdir -p "${STEAMAPPDIR}" \
    && cp /entry.sh "${HOMEDIR}/entry.sh" \
    # && wget "${DLURL}/roles/srcds/files/entry.sh" -O "${HOMEDIR}/entry.sh" \
	# Create autoupdate config
	&& { \
		echo '@ShutdownOnFailedCommand 1'; \
		echo '@NoPromptForPassword 1'; \
		echo 'force_install_dir '"${STEAMAPPDIR}"''; \
		echo 'login anonymous'; \
		echo 'app_update '"${STEAMAPPID}"''; \
		echo 'quit'; \
	   } > "${HOMEDIR}/${STEAMAPP}_update.txt" \
	&& chmod +x "${HOMEDIR}/entry.sh" \
	&& chown -R "${USER}:${USER}" "${HOMEDIR}/entry.sh" "${STEAMAPPDIR}" "${HOMEDIR}/${STEAMAPP}_update.txt" \
	# Clean up
	&& rm -rf /var/lib/apt/lists/*

ENV SRCDS_FPSMAX=300 \
	SRCDS_TICKRATE=66 \
	SRCDS_PORT=27015 \
	SRCDS_TV_PORT=27020 \
    SRCDS_NET_PUBLIC_ADDRESS="0" \
    SRCDS_IP="0" \
	SRCDS_MAXPLAYERS=16 \
	SRCDS_TOKEN=0 \
	SRCDS_RCONPW="changeme" \
	SRCDS_PW="changeme" \
	SRCDS_STARTMAP="ctf_2fort" \
	SRCDS_REGION=3 \
    SRCDS_HOSTNAME="New \"${STEAMAPP}\" Server" \
    SRCDS_WORKSHOP_START_MAP=0 \
    SRCDS_HOST_WORKSHOP_COLLECTION=0 \
    SRCDS_WORKSHOP_AUTHKEY=""

# Switch to user
USER ${USER}

WORKDIR ${HOMEDIR}

CMD ["bash", "entry.sh"]

# Expose ports
EXPOSE 27015/tcp \
	27015/udp \
	27020/udp