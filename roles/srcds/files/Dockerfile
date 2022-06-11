# Build sourcemod plugins
# Compiled plugins are output to /build/addons/sourcemod/plugins
FROM python:3-slim as sm_build
ENV METAMOD_VERSION 1.11
ENV SOURCEMOD_VERSION 1.10
ENV PATH="${PATH}:/build/addons/sourcemod/scripting"
WORKDIR /build
RUN set -x \
    && apt-get update \
    && apt-get install curl -y \
	&& curl -ssL https://mms.alliedmods.net/mmsdrop/${METAMOD_VERSION}/`curl -ssL "https://mms.alliedmods.net/mmsdrop/1.11/mmsource-latest-linux"` | tar xvzf - -C . \
	&& curl -ssL https://sm.alliedmods.net/smdrop/${SOURCEMOD_VERSION}/`curl -ssL "https://sm.alliedmods.net/smdrop/1.10/sourcemod-latest-linux"` | tar xvzf - -C . \
    && chmod +x /build/addons/sourcemod/scripting/spcomp
COPY addons/sourcemod addons/sourcemod/

WORKDIR /build/addons/sourcemod/scripting
COPY build.py .

RUN python3 build.py
RUN ls -la /build/addons/sourcemod/plugins

# Download tf2 game engine+assets to /build/game_data
FROM debian:buster-slim as game_build
WORKDIR /build
ENV DEPOT_DL_VERSION 2.4.6
ENV GAME_PATH ./game_data
ENV STEAMAPPID 232250

RUN set -x \
	&& apt-get update \
	&& apt-get install -y wget apt-transport-https \
	&& wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
	&& dpkg -i packages-microsoft-prod.deb \
	&& rm packages-microsoft-prod.deb \
	&& apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
		aspnetcore-runtime-6.0 unzip ca-certificates

RUN set -x \
	&& wget "https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOT_DL_VERSION}/depotdownloader-${DEPOT_DL_VERSION}.zip" \
	&& unzip depotdownloader-${DEPOT_DL_VERSION}.zip \
	&& mkdir -p "${GAME_PATH}" \
	&& dotnet ./DepotDownloader.dll -app "${STEAMAPPID}" -dir "${GAME_PATH}" -max-downloads 16 -max-servers 32

FROM debian:bullseye-slim

LABEL maintainer="leigh.macdonald@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/leighmacdonald/uncletopia"

ARG PUID=3000
ARG PGID=3000
ENV USER saxton
ENV HOMEDIR "/home/${USER}"
ENV STEAMAPPID 232250
ENV STEAMAPP tf
ENV STEAMAPPDIR "${HOMEDIR}/${STEAMAPP}"

RUN set -x \
	&& dpkg --add-architecture i386 \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
		lib32stdc++6 \
		lib32gcc-s1 \
		nano \
		libsdl2-2.0-0:i386 \
		curl \
		locales \
		wget apt-transport-https \
		unzip \
		ca-certificates \
		lib32z1 \
		libncurses5:i386 \
		libbz2-1.0:i386 \
		# lib32gcc1-sl \
		# lib32stdc++6 \
		libtinfo5:i386 \
		libcurl3-gnutls:i386 \
	&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& dpkg-reconfigure --frontend=noninteractive locales \
	&& useradd -u "${PUID}" -m "${USER}" \
	&& apt-get remove --purge --auto-remove -y \
		wget nano unzip \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR "${HOMEDIR}"

COPY entry.sh .
RUN chmod +x entry.sh && chown -R "${USER}" ./*

USER ${USER}

ENV SRCDS_FPSMAX=300 \
	SRCDS_TICKRATE=66 \
	SRCDS_PORT=27015 \
	SRCDS_TV_PORT=27020 \
    SRCDS_NET_PUBLIC_ADDRESS="" \
    SRCDS_IP="" \
	SRCDS_MAXPLAYERS=32 \
	SRCDS_TOKEN="" \
	SRCDS_RCONPW="changeme" \
	SRCDS_PW="" \
	SRCDS_STARTMAP="ctf_2fort" \
	SRCDS_REGION=3 \
    SRCDS_HOSTNAME="TF2" \
	SRCSD_LOG_SECRET=""

COPY --from=game_build --chown="${USER}:${GROUP}" /build/game_data/ .
COPY --from=sm_build --chown="${USER}:${GROUP}" /build/addons ./tf/addons/

RUN rm ./tf/addons/sourcemod/plugins/basevotes.smx

RUN ls -la 

VOLUME ${HOMEDIR}/tf/addons/sourcemod/data/sqlite
VOLUME ${HOMEDIR}/tf/logs
VOLUME ${HOMEDIR}/tf/addons/sourcemod/data/dumps

EXPOSE 27015/tcp 27015/udp 27020/udp

ENTRYPOINT [ "bash" ]

CMD ["entry.sh"]
