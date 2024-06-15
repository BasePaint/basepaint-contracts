#!/bin/bash -e

set -o allexport
source .env.local
set +o allexport

forge script "$1" -vvvv \
  --rpc-url $RPC_URL \
  --with-gas-price 10000000 \
  --broadcast \
  --verify
