#!/bin/bash

set -euo pipefail

eval "$(jq -r '@sh "secretname=\(.secretname) namespace=\(.namespace)"')"

# Get the default hostname of the ARO cluster
# Hardcoding an error value as we depend on helm to create the secret and not terraform
secret_token=$(oc get secret $secretname -n $namespace -o jsonpath='{.data.token}')
secret_ca=$(oc get secret $secretname -n $namespace -o jsonpath='{.data.ca\.crt}')


encoded_secret=$(echo ${secret_token})
encoded_ca=$(echo ${secret_ca})

jq -n --arg encoded_secret "$encoded_secret" --arg encoded_ca "$encoded_ca" '{"encoded_secret":$encoded_secret,"encoded_ca":$encoded_ca}'
