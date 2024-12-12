#!/bin/bash

set -euo pipefail

apiserver=$(kubectl config view --minify -o jsonpath={.clusters[0].cluster.server} | tr -d '\n')

encoded_apiserver=$(echo ${apiserver} | base64 -w 0)

jq -n --arg encoded_apiserver "$encoded_apiserver" '{"encoded_apiserver":$encoded_apiserver}'

