#!/bin/bash -e

set -o allexport
source .env.local
set +o allexport

forge script "$1" -vvvv \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
