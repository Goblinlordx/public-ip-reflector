#!/bin/sh

# Configuration
DEFAULT_SOURCES="ifconfig icanhazip ident ipecho"
SOURCES=${IP_SOURCE:-${IP_SERVICE:-$DEFAULT_SOURCES}}
PLACEHOLDER=${IP_PLACEHOLDER:-"{{PUBLIC_IP}}"}
REFLECT_TO=${REFLECT_TO:-"stdout"}

get_url() {
    case "$1" in
        "ifconfig") echo "https://ifconfig.me" ;;
        "icanhazip") echo "https://icanhazip.com" ;;
        "ident") echo "https://ident.me" ;;
        "ipecho") echo "https://ipecho.net/plain" ;;
        *) echo "$1" ;;
    esac
}

detect_ip() {
    for source in $(echo "${SOURCES}" | tr ',' ' '); do
        IP_URL=$(get_url "${source}")
        echo "Attempting to detect IP using ${source} (${IP_URL})..." >&2
        
        IP=$(curl -s --max-time 10 "${IP_URL}")
        
        if [ -n "${IP}" ]; then
            DETECTED_IP=$(echo "${IP}" | tr -d '[:space:]')
            echo "Successfully detected IP: ${DETECTED_IP}" >&2
            echo "${DETECTED_IP}"
            return 0
        fi
    done
    return 1
}

reflect_k8s() {
    _ip="$1"
    _svc="${K8S_SERVICE:-"ddns-source"}"
    _ns="${K8S_NAMESPACE:-"infra"}"
    
    echo "Reflecting to Kubernetes: Service ${_svc} in Namespace ${_ns}"
    kubectl patch svc "${_svc}" -n "${_ns}" -p "{\"spec\":{\"externalIPs\":[\"${_ip}\"]}}"
}

reflect_stdout() {
    echo "$1"
}

# --- Main Execution ---

PUBLIC_IP=$(detect_ip)
if [ -z "${PUBLIC_IP}" ]; then
    echo "Error: Failed to detect public IP from all sources."
    exit 1
fi

# Determine if we have a command or use REFLECT_TO
if [ $# -gt 0 ]; then
    # Custom command provided via CLI arguments
    CMD_ARGS=""
    for arg in "$@"; do
        modified_arg=$(echo "${arg}" | sed "s/${PLACEHOLDER}/${PUBLIC_IP}/g")
        CMD_ARGS="${CMD_ARGS} \"${modified_arg}\""
    done
    echo "Executing custom command: eval ${CMD_ARGS}"
    eval "set -- ${CMD_ARGS}"
    exec "$@"
else
    # Use predefined reflection targets or custom command in REFLECT_TO
    case "${REFLECT_TO}" in
        "stdout")
            reflect_stdout "${PUBLIC_IP}"
            ;;
        "k8s")
            reflect_k8s "${PUBLIC_IP}"
            ;;
        *)
            # Treat as a command and substitute placeholder
            MODIFIED_CMD=$(echo "${REFLECT_TO}" | sed "s/${PLACEHOLDER}/${PUBLIC_IP}/g")
            echo "Executing reflection command: ${MODIFIED_CMD}"
            eval "${MODIFIED_CMD}"
            ;;
    esac
fi
