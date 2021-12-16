FROM python:3-slim

ENV SOURCEMOD_VERSION 1.10
ENV PATH="${PATH}:/build/addons/sourcemod/scripting"

WORKDIR /build

RUN set -x \
    && DEBIAN_FRONTEND=nointeractive dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install wget libc6:i386 lib32stdc++6 -y \
	&& wget -qO- https://mms.alliedmods.net/mmsdrop/1.11/mmsource-1.11.0-git1145-linux.tar.gz | tar xvzf - -C . \
	&& wget -qO- https://sm.alliedmods.net/smdrop/1.10/sourcemod-1.10.0-git6528-linux.tar.gz | tar xvzf - -C . \
    && chmod 700 /build/addons/sourcemod/scripting/spcomp

COPY addons/sourcemod/data addons/sourcemod/data/
COPY addons/sourcemod/extensions addons/sourcemod/extensions/
COPY addons/sourcemod/gamedata addons/sourcemod/gamedata/
COPY addons/sourcemod/plugins addons/sourcemod/plugins/
COPY addons/sourcemod/scripting addons/sourcemod/scripting/
COPY addons/sourcemod/translations addons/sourcemod/translations/

WORKDIR /build/addons/sourcemod/scripting

COPY build.py .

ENTRYPOINT ["python3"]
CMD ["build.py"]
