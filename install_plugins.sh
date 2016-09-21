#!/usr/bin/env bash

# Modified from https://github.com/jenkinsci/docker/blob/master/plugins.sh

# Parse a support-core plugin-style txt file as specification for jenkins plugins to be installed

set -e

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGINS_DIR="$THIS_DIR/plugins"
PLUGINS_DOWNLOAD_URL="https://updates.jenkins.io/download/plugins"

function usage(){
    cat << EOF
usage: $(basename $0) [-h] [-d PLUGINS_DIR] [-u PLUGINS_DOWNLOAD_URL] PLUGINS_FILE

options:
    -h: print this usage statement and exit
    -d PLUGINS_DIR: the directory into which to download the Jenkins plugins (default: $PLUGINS_DIR)
    -u PLUGINS_DOWNLOAD_URL: the Jenkins URL (default: $PLUGINS_DOWNLOAD_URL)
EOF

}

while getopts ":hd:u:" opt; do
    case $opt in
        h)
            usage >&2
            exit 0
            ;;
        d)
            PLUGINS_DIR="$OPTARG"
            ;;
        u)
            PLUGINS_DOWNLOAD_URL="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done
shift $(($OPTIND - 1))

PLUGINS_FILE="$1"

mkdir -p "$PLUGINS_DIR"

while read spec || [ -n "$spec" ]; do
    plugin=(${spec//:/ });
    [[ ${plugin[0]} =~ ^# ]] && continue
    [[ ${plugin[0]} =~ ^\s*$ ]] && continue
    [[ -z ${plugin[1]} ]] && plugin[1]="latest"
    echo "Downloading ${plugin[0]}:${plugin[1]}"

    curl -sSL -f "${PLUGINS_DOWNLOAD_URL}/${plugin[0]}/${plugin[1]}/${plugin[0]}.hpi" -o "$PLUGINS_DIR/${plugin[0]}.jpi"
    unzip -qqt "$PLUGINS_DIR/${plugin[0]}.jpi"
done  < "$PLUGINS_FILE"
