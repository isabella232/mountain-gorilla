#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2016, Joyent, Inc.
#

#
# Update a new sprint version on Joyent Eng Jira projects.
#
# Usage:
#   ./addsprintversion.sh [-c] VERSION [PROJECTS...]
#
# Options:
#       -c      Continue, even if there are earlier failures. This can
#               be useful to do a run through even if some projects already
#               have the version.
#
# Example:
#   ./addsprintversion.sh '2011-12-29 Duffman'
#   ./addsprintversion.sh '2011-12-29 Duffman' WORKFLOW
#   ./addsprintversion.sh -c '2011-12-29 Duffman'
#

if [[ -n "$TRACE" ]]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi
set -o errexit
set -o pipefail


TOP=$(cd $(dirname "$0") >/dev/null; pwd)



# ---- mainline

optContinue=
while getopts "c" opt; do
    case "$opt" in
        c)
            optContinue=true
            ;;
        *)
            echo "error: unknown option $opt" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))


JIRACLI_OPTS="--server https://devhub.joyent.com/jira"
JIRACLI_RC_PATH="$HOME/.jiraclirc"
if [ ! -f "$JIRACLI_RC_PATH" ]; then
    echo "'$JIRACLI_RC_PATH' does not exist. You need one that looks like this:"
    echo "    --user=joe.blow --password='his-jira-password'"
    exit 1
fi
JIRACLI_OPTS+=" $(cat $JIRACLI_RC_PATH)"


if [[ -z "$1" ]]; then
    echo "Provide VERSION name, e.g. $0 '2012-03-22 Jimbo'";
    exit 1
fi
VERSION=$1

YEAR=$(echo $VERSION | cut -c 1-4)
MONTH=$(echo $VERSION | cut -c 6-7)
DAY=$(echo $VERSION | cut -c 9-10)
RELEASE_DATE=$MONTH/$DAY/$YEAR
# TODO: validate this?

PROJECTS=$*
if [[ -z "$PROJECTS" ]]; then
    PROJECTS=$($TOP/listengprojects.sh | xargs)
fi


echo "This will *add* the following version to these Joyent Jira projects:"
echo "        version: '$VERSION'"
echo "   release date: '$RELEASE_DATE'"
echo "       projects: $(echo "$PROJECTS" | xargs)"
echo ""
read -p "Hit Enter to continue..."
echo

for project in $PROJECTS
do
    echo "# $project: add version '$VERSION' with release date '$RELEASE_DATE'"
    if [[ "$optContinue" == "true" ]]; then
        # Allow failures with '-c'.
        $TOP/jira.sh $JIRACLI_OPTS --action addVersion  \
          --project $project --name "$VERSION" --date "$RELEASE_DATE" \
          --dateFormat "MM/dd/yyyy" || true
    else
        $TOP/jira.sh $JIRACLI_OPTS --action addVersion  \
          --project $project --name "$VERSION" --date "$RELEASE_DATE" \
          --dateFormat "MM/dd/yyyy"
    fi
done
