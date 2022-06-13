#!/bin/bash
mkdir -p "${STEAMAPPDIR}" || true

bash "${STEAMCMDDIR}/steamcmd.sh" +force_install_dir "${STEAMAPPDIR}" \
				+login anonymous \
				+app_update "${STEAMAPPID}" \
				+quit

if  [ ! -z "$SOURCEMOD_VERSION" ] && [ ! -d "${STEAMAPPDIR}/${STEAMAPP}/addons/sourcemod" ]; then
  pwd
  cd "${STEAMAPPDIR}"/"${STEAMAPP}" || exit
  pwd
  wget -qO- https://github.com/leighmacdonald/uncletopia/releases/download/sm-test-release/ut-sourcemod.tar.gz | tar xvzf - -C "${STEAMAPPDIR}/${STEAMAPP}/"
fi

cp -rv "/home/steam/config/${STEAMAPP}" "${STEAMAPPDIR}"

# Believe it or not, if you don't do this srcds_run shits itself
cd "${STEAMAPPDIR}"

ln -s "${STEAMAPPDIR}"/"${STEAMAPP}/stv_demos" /demos
ln -s "${STEAMAPPDIR}"/"${STEAMAPP}/logs" /logs

bash "${STEAMAPPDIR}/srcds_run" -game "${STEAMAPP}" -console -autoupdate \
  -steam_dir "${STEAMCMDDIR}" \
  -steamcmd_script "${HOMEDIR}/${STEAMAPP}_update.txt" \
  -usercon \
  +fps_max "${SRCDS_FPSMAX}" \
  -tickrate "${SRCDS_TICKRATE}" \
  -port "${SRCDS_PORT}" \
  +tv_port "${SRCDS_TV_PORT}" \
  +clientport "${SRCDS_CLIENT_PORT}" \
  +maxplayers "${SRCDS_MAXPLAYERS}" \
  +map "${SRCDS_STARTMAP}" \
  +sv_setsteamaccount "${SRCDS_TOKEN}" \
  +rcon_password "${SRCDS_RCONPW}" \
  +sv_password "${SRCDS_PW}" \
  +sv_region "${SRCDS_REGION}" \
  -ip "${SRCDS_IP}" \
  -authkey "${SRCDS_WORKSHOP_AUTHKEY}"

#
#bash ./srcds_run \
#  -game "${STEAMAPP}" \
#  -console \
#  -usercon \
#  +fps_max "${SRCDS_FPSMAX}" \
#  -tickrate "${SRCDS_TICKRATE}" \
#  -port "${SRCDS_PORT}" \
#  +clientport "${SRCDS_CLIENT_PORT}" \
#  +tv_port "${SRCDS_TV_PORT}" \
#  +maxplayers "${SRCDS_MAXPLAYERS}" \
#  +map "${SRCDS_STARTMAP}" \
#  +sv_setsteamaccount "${SRCDS_TOKEN}" \
#  +rcon_password "${SRCDS_RCONPW}" \
#  +sv_password "${SRCDS_PW}" \
#  +sv_region "${SRCDS_REGION}" \
#  -ip "${SRCDS_IP}"
