#!/usr/bin/env bash

set -o nounset
set -o pipefail

VERSION="1.0.0"
API_URL="https://crt.name/v1/search"

usage() {
    cat <<'EOF'
crt-subdomains - discover subdomains from crt.name certificate data

Usage:
  crt-subdomains.sh -d <domain> [options]
  crt-subdomains.sh -l <file>   [options]

Options:
  -d, -domain <domain>  Apex domain to search
  -l, -list <file>      File containing one apex domain per line
  -o, -output <file>    Write results to a file (also prints to stdout)
  -silent               Suppress the banner and status messages
  -version              Show version
  -h, -help             Show this help

Examples:
  crt-subdomains.sh -d namecheap.com
  crt-subdomains.sh -l domains.txt -o subdomains.txt
EOF
}

usage_error() {
    printf '[-] %s\n' "$*" >&2
    usage >&2
    exit 2
}

log_info() {
    if [[ $silent -eq 0 ]]; then
        printf '[INF] %s\n' "$*" >&2
    fi
}

log_error() {
    printf '[-] %s\n' "$*" >&2
}

valid_domain() {
    [[ $1 =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}

emit_result() {
    printf '%s\n' "$1"
    if [[ -n $output_file ]]; then
        printf '%s\n' "$1" >&3
    fi
}

process_domain() {
    local domain=$1
    local response host

    if ! valid_domain "$domain"; then
        log_error "Invalid domain: $domain"
        failures=$((failures + 1))
        return
    fi

    domain=${domain,,}
    log_info "Searching $domain"

    if ! response=$(curl --fail --silent --show-error \
        --connect-timeout 10 --max-time 60 \
        --get --data-urlencode "apex=$domain" "$API_URL"); then
        log_error "Search failed for $domain"
        failures=$((failures + 1))
        return
    fi

    local found=0
    while IFS= read -r host || [[ -n $host ]]; do
        host=${host//$'\r'/}
        host="${host#"${host%%[![:space:]]*}"}"
        host="${host%"${host##*[![:space:]]}"}"
        host=${host,,}

        [[ -n $host ]] || continue
        [[ $host == *."$domain" ]] || continue
        [[ $host != "$domain" ]] || continue
        [[ $host =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ ]] || continue

        if [[ -z ${seen[$host]+present} ]]; then
            seen[$host]=1
            emit_result "$host"
            found=$((found + 1))
            total_results=$((total_results + 1))
        fi
    done <<< "$response"

    log_info "Found $found new subdomains for $domain"
}

domain=""
list_file=""
output_file=""
silent=0
failures=0
total_results=0
declare -A seen=()

while (($#)); do
    case "$1" in
        -d|-domain)
            (($# >= 2)) || usage_error "Missing value for $1"
            [[ -z $domain ]] || usage_error "Specify only one of -d or -l"
            domain=$2
            shift 2
            ;;
        -l|-list)
            (($# >= 2)) || usage_error "Missing value for $1"
            [[ -z $list_file ]] || usage_error "Specify only one of -d or -l"
            list_file=$2
            shift 2
            ;;
        -o|-output)
            (($# >= 2)) || usage_error "Missing value for $1"
            [[ -z $output_file ]] || usage_error "Output file specified more than once"
            output_file=$2
            shift 2
            ;;
        -silent)
            silent=1
            shift
            ;;
        -version)
            printf 'crt-subdomains %s\n' "$VERSION"
            exit 0
            ;;
        -h|-help|--help)
            usage
            exit 0
            ;;
        *)
            usage_error "Unknown option: $1"
            ;;
    esac
done

[[ -n $domain || -n $list_file ]] || usage_error "Provide a domain with -d or a file with -l"
[[ -z $domain || -z $list_file ]] || usage_error "Specify only one of -d or -l"
command -v curl >/dev/null 2>&1 || {
    log_error "curl is required but was not found"
    exit 1
}

if [[ -n $list_file ]]; then
    if [[ ! -r $list_file || ! -f $list_file ]]; then
        log_error "Cannot read domain list: $list_file"
        exit 1
    fi
    if [[ -n $output_file && -e $output_file && $output_file -ef $list_file ]]; then
        log_error "Output file must not be the domain list: $output_file"
        exit 1
    fi
fi

if [[ -n $output_file ]]; then
    if ! exec 3> "$output_file"; then
        log_error "Cannot write to output file: $output_file"
        exit 1
    fi
fi

if [[ $silent -eq 0 ]]; then
    printf 'crt-subdomains v%s\n' "$VERSION" >&2
    printf 'Source: crt.name certificate search\n\n' >&2
fi

if [[ -n $domain ]]; then
    process_domain "$domain"
else
    while IFS= read -r domain || [[ -n $domain ]]; do
        domain="${domain#"${domain%%[![:space:]]*}"}"
        domain="${domain%"${domain##*[![:space:]]}"}"
        [[ -n $domain && $domain != \#* ]] || continue
        process_domain "$domain"
    done < "$list_file"
fi

log_info "Completed: $total_results unique subdomains"
if ((failures > 0)); then
    exit 1
fi