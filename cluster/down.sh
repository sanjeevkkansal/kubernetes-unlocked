#!/usr/bin/env bash
# Delete the local cluster. Everything in it goes with it.
set -euo pipefail
kind delete cluster --name unlocked
