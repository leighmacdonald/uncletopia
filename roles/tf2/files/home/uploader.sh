#!/usr/bin/env bash

SERVER_NAME=$1
TOKEN=$2
MONITOR_PATH=${3:-/home/tf2server/serverfiles/tf/logs}
CACHE_PATH=${4:-/home/tf2server/.last_uploaded_log}

LAST_SENT=`cat "$CACHE_PATH" 2>/dev/null` || true

function cleanup() {
  echo "last upload: $path"
  echo "-- done --"
  echo "$path" > $CACHE_PATH
}

paths=()
if [ -z "$LAST_SENT" ]; then
  echo "no cache file found"
  readarray -t paths < <(find "$MONITOR_PATH" -maxdepth 1 -type f | sort | head -n -1)
else
  echo "uploading from: $LAST_SENT"
  readarray -t paths < <(find "$MONITOR_PATH" -maxdepth 1 -type f | sort | awk "\$0 > \"$LAST_SENT\"" | head -n -1)
fi

if [ "${#paths[@]}" -gt "0" ]; then
  path=$LAST_SENT
  trap "cleanup ${paths[-1]}" EXIT
  for path in "${paths[@]}"; do
    printf "uploading $path ... "
    curl -o - -s -w "%{http_code}\n" 'https://uncletopia.halcyon.hr/log_files/' -F "log_file[file]=@$path" -F "log_file[server_name]=$SERVER_NAME" -H "Authorization: Token $TOKEN"
    sleep 0.5
  done
fi

