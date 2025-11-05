#!/usr/bin/env sh

log_message() {
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    message="[${timestamp}] $1"
    echo "${message}"
    if [ -n "${LOG_FILE}" ]; then
        echo "${message}" >> "${LOG_FILE}"
    fi
}

check_already_running() {
    script_dir="$(dirname "$0")"
    script_dir="$(realpath "${script_dir}")"
    pid_file="${script_dir}/chibisafe_watcher.pid"

    if [ -f "${pid_file}" ]; then
        old_pid=$(cat "${pid_file}")
        if ps -p "${old_pid}" > /dev/null 2>&1; then
            echo "Watcher is already running with PID ${old_pid}"
            exit 0
        else
            rm -f "${pid_file}"
        fi
    fi

    echo $$ > "${pid_file}"
}

cleanup() {
    script_dir="$(dirname "$0")"
    script_dir="$(realpath "${script_dir}")"
    pid_file="${script_dir}/chibisafe_watcher.pid"

    log_message "INFO: Shutting down watcher..."
    rm -f "${pid_file}"
    exit 0
}

setup_environment() {
    script_dir="$(dirname "$0")"
    script_dir="$(realpath "${script_dir}")"
    env_file="${script_dir}/chibisafe_watcher.env"

    if [ -f "${env_file}" ]; then
        . "${env_file}"
    else
        log_message "ERROR: No environment file found at ${env_file}"
        exit 1
    fi

    # Set up log file if not specified
    if [ -z "${LOG_FILE}" ]; then
        LOG_FILE="${script_dir}/chibisafe_watcher.log"
    fi

    # Verify required environment variables
    if [ -z "${CHIBISAFE_API_KEY}" ] || [ -z "${CHIBISAFE_ALBUM_UUID}" ] || \
       [ -z "${CHIBISAFE_REQUEST_URL}" ] || [ -z "${CHIBISAFE_WATCH_DIR}" ]; then
        log_message "ERROR: Missing required environment variables"
        log_message "Required: CHIBISAFE_API_KEY, CHIBISAFE_ALBUM_UUID, CHIBISAFE_REQUEST_URL, CHIBISAFE_WATCH_DIR"
        exit 1
    fi

    # Verify watch directory exists
    if [ ! -d "${CHIBISAFE_WATCH_DIR}" ]; then
        log_message "ERROR: Watch directory does not exist: ${CHIBISAFE_WATCH_DIR}"
        exit 1
    fi

    log_message "INFO: Chibisafe watcher initialized"
    log_message "INFO: Watching directory: ${CHIBISAFE_WATCH_DIR}"
    log_message "INFO: Upload URL: ${CHIBISAFE_REQUEST_URL}"
    log_message "INFO: Log file: ${LOG_FILE}"
}

upload() {
    filename=$1

    # Verify file still exists
    if [ ! -f "${filename}" ]; then
        log_message "WARN: File no longer exists: ${filename}"
        return 1
    fi

    log_message "INFO: Uploading: ${filename}"
    response=$(curl -H "x-api-key: ${CHIBISAFE_API_KEY}" \
        -H "albumuuid: ${CHIBISAFE_ALBUM_UUID}" \
        -F "file[]=@${filename}" \
        -w "\n%{http_code}" \
        "${CHIBISAFE_REQUEST_URL}" 2>&1)

    http_code=$(echo "${response}" | tail -n1)

    if [ "${http_code}" = "200" ] || [ "${http_code}" = "201" ]; then
        log_message "SUCCESS: Uploaded ${filename}"
        return 0
    else
        log_message "ERROR: Failed to upload ${filename} (HTTP ${http_code})"
        log_message "Response: ${response}"
        return 1
    fi
}

start_watch() {
    log_message "INFO: Starting file watcher..."
    fswatch -0 "${CHIBISAFE_WATCH_DIR}" | while read -d "" new_file
    do
        log_message "INFO: Detected file change: ${new_file}"
        if [ -f "${new_file}" ]; then
            upload "${new_file}"
        else
            log_message "WARN: Detected path is not a file: ${new_file}"
        fi
    done
}

# Set up signal handlers for graceful shutdown
trap cleanup SIGTERM SIGINT SIGHUP

check_already_running
setup_environment
start_watch
