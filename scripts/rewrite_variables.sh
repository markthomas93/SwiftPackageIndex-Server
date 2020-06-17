#!/bin/bash

# This script rewrites env variables based on the specified environment.
# Say for instance, deployment requires variable FOO to be set and your
# environment contains the variables
#   INT_FOO=1
#   PROD_FOO=2
# This script, when called with parameter "prod" will set
#   FOO=2
# Conversely, if called with "int", it will set
#   FOO=1
# It will do this for any variables whose prefix matches the chosen
# environment.

set -eu

ENV=$1

ENV_UPPER=$(echo $ENV | tr "[:lower:]" "[:upper:]")
echo Rewriting variables for environmen: $ENV_UPPER

function join_by { local IFS="$1"; shift; echo "$*"; }

for line in $(printenv | grep "^$ENV_UPPER"); do
    IFS="=" read -ra var <<< "$line"
    var=${var[0]}
    value=$(eval echo \"\$$var\")
    IFS="_" read -ra parts <<< "$var"
    unset parts[0]
    new=$(join_by _ "${parts[@]}")
    export $new=$value
    echo Rewritten: $new = $value
done