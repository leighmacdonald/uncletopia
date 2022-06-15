#!/bin/bash
mkdir -p "${STEAMAPPDIR}" || true

bash "${STEAMCMDDIR}/steamcmd.sh" +force_install_dir "${STEAMAPPDIR}" \
				+login anonymous \
				+app_update "${STEAMAPPID}" \
				+quit

if [ ! -f "$HOME/.sm-loaded" ]; then
  echo "Loading sourcemod distribution for first time"
  tar xvzf /ut-sourcemod.tar.gz -C "${STEAMAPPDIR}/${STEAMAPP}/" || exit
  touch "$HOME/.sm-loaded"
fi

cp -rv "/home/steam/config/${STEAMAPP}" "${STEAMAPPDIR}"

# Believe it or not, if you don't do this srcds_run shits itself
cd "${STEAMAPPDIR}"

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
