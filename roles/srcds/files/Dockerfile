# Build sourcemod plugins
# Compiled plugins are output to /build/addons/sourcemod/plugins
FROM python:3-slim as sm_build

ENV METAMOD_VERSION 1.11
ENV SOURCEMOD_VERSION 1.10
ENV PATH="${PATH}:/build/addons/sourcemod/scripting"

WORKDIR /build
RUN set -x \
    && apt-get update \
    && apt-get install wget -y \
	&& wget -qO- https://mms.alliedmods.net/mmsdrop/1.11/mmsource-1.11.0-git1145-linux.tar.gz | tar xvzf - -C . \
	&& wget -qO- https://sm.alliedmods.net/smdrop/1.10/sourcemod-1.10.0-git6528-linux.tar.gz | tar xvzf - -C . \
    && chmod 777 /build/addons/sourcemod/scripting/spcomp
COPY addons/sourcemod/data addons/sourcemod/data/
COPY addons/sourcemod/extensions addons/sourcemod/extensions/
COPY addons/sourcemod/gamedata addons/sourcemod/gamedata/
COPY addons/sourcemod/plugins addons/sourcemod/plugins/
COPY addons/sourcemod/scripting addons/sourcemod/scripting/
COPY addons/sourcemod/translations addons/sourcemod/translations/

WORKDIR /build/addons/sourcemod/scripting
COPY build.py .
RUN python3 build.py

# Download tf2 game engine+assets to /build/game_data
FROM debian:buster-slim as download_tf2
WORKDIR /build

ENV STEAMAPPID 232250

RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests locales \
	&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& dpkg-reconfigure --frontend=noninteractive locales \
	&& apt-get update \
	&& apt-get install -y wget apt-transport-https \
	&& wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
	&& dpkg -i packages-microsoft-prod.deb \
	&& rm packages-microsoft-prod.deb \
	&& apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
		aspnetcore-runtime-5.0 unzip ca-certificates 

RUN set -x \
	&& wget https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_2.4.5/depotdownloader-2.4.5.zip \
	&& unzip depotdownloader-2.4.5.zip \
	&& mkdir -p game_data \
	&& dotnet ./DepotDownloader.dll -app "${STEAMAPPID}" -dir ./game_data -max-downloads 16 -max-servers 32


FROM debian:buster-slim

LABEL maintainer="leigh.macdonald@gmail.com"
ARG PUID=1000
ENV USER steam
ENV HOMEDIR "/home/${USER}"

ENV STEAMAPPID 232250
ENV STEAMAPP tf
ENV STEAMAPPDIR "${HOMEDIR}/${STEAMAPP}-dedicated"


RUN set -x \
	&& dpkg --add-architecture i386 \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
		lib32stdc++6 \
		lib32gcc1 \
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
		lib32gcc1 \
		lib32stdc++6 \
		libtinfo5:i386 \
		libcurl3-gnutls:i386 \
	&& useradd -u "${PUID}" -m "${USER}" 

COPY entry.sh ${HOMEDIR}/entry.sh
RUN chmod +x "${HOMEDIR}/entry.sh" \
        && chown -R "${USER}:${USER}" "${HOMEDIR}/entry.sh"

USER ${USER}
WORKDIR ${HOMEDIR}

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

WORKDIR /home/steam
USER root

RUN chown -R "${USER}:${USER}" . && chmod -R 777 .
USER ${USER}
WORKDIR "${STEAMAPPDIR}"

EXPOSE 27015/tcp 27015/udp 27020/udp

COPY --from=download_tf2 /build/game_data/* ${STEAMAPPDIR}/
COPY --from=sm_build /build/addons/* ${STEAMAPPDIR}/tf/addons/

VOLUME ${STEAMAPPDIR}/tf/addons/sourcemod/data
VOLUME ${STEAMAPPDIR}/tf/addons/sourcemod/gamedata
VOLUME ${STEAMAPPDIR}/tf/addons/sourcemod/logs
VOLUME ${STEAMAPPDIR}/tf/downloads
VOLUME ${STEAMAPPDIR}/tf/cache
VOLUME ${STEAMAPPDIR}/tf/logs

CMD ["bash", "../entry.sh"]