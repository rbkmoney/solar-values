#!/bin/sh

set -o pipefail

KK_HOST=${KK_HOST:-keycloak-headless}
KK_PORT=${KK_PORT:-8080}
KK_REALM=${KK_REALM:-external}
TARGET=${TARGET:-secret}

MAX_RETRY_TIMEOUT=${MAX_RETRY_TIMEOUT:-10}

TIMEOUT=0

LOG_FILE=${SCRIPT_LOGFILE:-/dev/null}

function log() {
    local severity=$1
    local msg=$2
    local log_msg="$(date -Iseconds) [ $severity ] $msg"
    echo  "$0: $log_msg"
    echo  $log_msg >> $LOG_FILE
}

while true; do
    REALM_FAIL=false

    log INFO "Attempting to fetch Keycloak key..."

    REALM_DATA=$(wget --quiet --timeout=10 "http://${KK_HOST}:${KK_PORT}/auth/realms/${KK_REALM}" -O -)
    EXIT_CODE=$?
    if [ "${EXIT_CODE}" -ne "0" ]; then
        REALM_FAIL=true
        log ERROR "Keycloak realm data fetching failed with exit code: ${EXIT_CODE}"
    fi
    if [ -z "${REALM_DATA}" ]; then
        REALM_FAIL=true
        log ERROR "Keycloak realm data is empty"
    fi
    if [ "$REALM_FAIL" == false ]; then
        break
    else
        TIMEOUT=$((TIMEOUT + 1))
        TIMEOUT=$([ $TIMEOUT -le $MAX_RETRY_TIMEOUT ] && echo "$TIMEOUT" || echo "$MAX_RETRY_TIMEOUT")
    fi

    log ERROR "Keycloak request timeout: ${TIMEOUT}"
    sleep $TIMEOUT
done

log INFO "Keycloak realm data fetched successfully"
log DEBUG "${REALM_DATA}"
log INFO  "Writing public key to: ${TARGET} ..."

echo "-----BEGIN PUBLIC KEY-----" > ${TARGET}
echo "${REALM_DATA}" | \
    sed -E -e 's/^.*"public_key":"([^"]*)".*$/\1/' | \
    fold -w80 \
    >> ${TARGET}
echo "-----END PUBLIC KEY-----" >> ${TARGET}

log INFO "Everything is ok"
