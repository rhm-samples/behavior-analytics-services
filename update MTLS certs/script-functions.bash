#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m'

function echoGreen() {
  echo -e "${GREEN}$1${NC}"
}

function echoRed() {
  echo -e "${RED}$1${NC}"
}

function echoBlue() {
  echo -e "${BLUE}$1${NC}"
}

function echoYellow() {
  echo -e "${YELLOW}$1${NC}"
}

function displayStepHeader() {
  stepHeader=$(stepLog "$1" "$2")
  echoBlue "$stepHeader"
}

function stepLog() {
  echo -e "STEP $1/7: $2"
}

function checkOCServerVersion() {
  currentOCServerVersion="$(oc version -o json | jq .serverVersion.gitVersion)"
  echo $currentOCServerVersion
  echo $requiredServerVersion
  if ! [[ $currentOCServerVersion =~ $requiredServerVersion ]]; then
    if [ "$currentOCServerVersion" = null ]; then
      echoRed "Unsupported OpenShift Server version detected. Supported OpenShift Server versions are 1.16 and above."
    else
      echoRed "Unsupported OpenShift Server version $currentOCServerVersion detected. Supported OpenShift versions are 1.16 and above."
    fi
    exit 1
  fi
}


function checkOCClientVersion() {
  currentClientVersion="$(oc version -o json | jq .clientVersion.gitVersion)"
  if ! [[ $currentClientVersion =~ $requiredVersion ]]; then
    echoRed "Unsupported oc cli version $currentClientVersion detected. Supported oc cli versions are 4.3 and above."
    exit 1
  fi
}
