#/bin/bash

set -euo pipefail

eval "$(jq -r '@sh "routename=\(.routename) namespace=\(.namespace)"')"

# Get the default hostname of the ARO cluster
route=$(oc get route $routename -n $namespace -o jsonpath='{.spec.host}' | tr -d '\n' )

encoded_route=$(echo ${route} | base64 -w 0)
jq -n --arg encoded_route "$encoded_route" '{"encoded_route":$encoded_route}'
