#!/usr/bin/env bash

set -e
set -o pipefail

SCRIPT_NAME="${BASH_SOURCE[0]##*/}"
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEFAULT_URL="http://localhost:8080"

JENKINS_URL="$DEFAULT_URL"
JENKINS_HOME="$THIS_DIR"
REMOTE_NAME=origin
REMOTE_BRANCH=HEAD
DO_PUSH=0


function usage(){
cat << EOF
usage: $(basename $0) [-h] [-p] [-U JENKINS_URL] [-H JENKINS_HOME] [-R REMOTE_NAME]

options:
    -h: print this usage statement and exit
    -p: push to the remote repository (not done by default)
    -U JENKINS_URL: the Jenkins URL (default: $DEFAULT_URL)
    -H JENKINS_HOME: the JENKINS_HOME (default: $THIS_DIR)
    -R REMOTE_NAME: the remote to which commits get pushed (default: $REMOTE_NAME)
    -B REMOTE_BRANCH: the remote branch name to which commits get pushed (default: $REMOTE_BRANCH)
EOF

}

while getopts ":hpH:U:R:B:" opt; do
    case $opt in
        h)
            usage >&2
            exit 0
            ;;
        p)
            DO_PUSH=1
            ;;
        H)
            JENKINS_HOME="$OPTARG"
            ;;
        U)
            JENKINS_URL="$OPTARG"
            ;;
        R)
            REMOTE_NAME="$OPTARG"
            ;;
        B)
            REMOTE_BRANCH="$OPTARG"
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

cd "$JENKINS_HOME"

PLUGINS_LIST_FILE="$JENKINS_HOME/jenkins_plugins"

update_plugins_list() {
    local jenkins_url=$1
    local plugins_file=$2
    echo "Obtaining plugins list from $jenkins_url"
    # Taken from https://github.com/jenkinsci/docker#preinstalling-plugins
    curl -sSL \
        "$jenkins_url/pluginManager/api/xml?depth=1&xpath=/*/*/shortName|/*/*/version&wrapper=plugins" \
        | perl -pe 's/.*?<shortName>([\w-]+).*?<version>([^<]+)()(<\/\w+>)+/\1:\2\n/g' \
        > $plugins_file
    echo "Plugins list written to $plugins_file"
}

add_if_exists() {
    local subdir=$1
    if [ "$(ls -A $subdir/)" ]; then
        git add "$subdir/"*
    fi
}

check_if_changes_staged() {
    if ! git diff --cached --quiet; then
        changes_staged=1
    else
        changes_staged=0
    fi
}


update_plugins_list $JENKINS_URL $PLUGINS_LIST_FILE
git add $PLUGINS_LIST_FILE

echo "Adding general and plugin files."
git add *.xml

echo "Adding secrets files."
git add secret.key*
add_if_exists secrets

echo "Adding user configurations."
add_if_exists users
add_if_exists userContent

echo "Adding job configurations."
# For standard projects
find jobs -maxdepth 2 -name 'config.xml' -exec git add {} \+
# For multi-configuration projects
find jobs -path '*/configurations/*/config.xml' -exec git add {} \+

check_if_changes_staged
if [[ changes_staged -eq 1 ]]; then
    echo "Committing changes."
    git commit -aqm "Backup by $SCRIPT_NAME"

else
    echo "No changes to be committed."
fi

if [[ $DO_PUSH -eq 1 ]]; then
    echo "Pushing to remote repository."
    git push "$REMOTE_NAME" "$REMOTE_BRANCH"
fi

exit 0
