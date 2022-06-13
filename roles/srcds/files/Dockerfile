# Download tf2 game engine+assets to /build/game_data
FROM cm2network/tf2

LABEL maintainer="leigh.macdonald@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/leighmacdonald/uncletopia"

WORKDIR "${HOMEDIR}"

COPY entry.sh .
RUN chmod +x entry.sh && chown -R "${USER}" ./*

ENV SRCSD_LOG_SECRET=""

WORKDIR ${HOMEDIR}/tf/
COPY ../../srcds/files .
WORKDIR ${HOMEDIR}/tf/addons/sourcemod/scripting

RUN chown -R ${USER} ${HOMEDIR}
USER ${USER}
RUN ls -la
RUN ls -la include

RUN ./build.sh
RUN mv -v ../plugins/basecomm.smx ../plugins/disabled/
VOLUME ${HOMEDIR}/tf/replay/tmp
VOLUME ${HOMEDIR}/tf/addons/sourcemod/data/sqlite
VOLUME ${HOMEDIR}/tf/logs
VOLUME ${HOMEDIR}/logs
VOLUME ${HOMEDIR}/tf/addons/sourcemod/data/dumps

EXPOSE 27015/tcp 27015/udp 27020/udp

ENTRYPOINT [ "bash" ]

WORKDIR ${HOMEDIR}

CMD ["entry.sh"]
