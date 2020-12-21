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
  echo -e "STEP $1/15: $2"
}

function checkClusterServiceVersionSucceeded() {

	retryCount=20
	retries=0
	check_for_csv_success=$(oc get csv -n "$projectName" --ignore-not-found | awk '$1 ~ /behavior-analytics-services-operator/ { print }' | awk -F' ' '{print $NF}')
	until [[ $retries -eq $retryCount || $check_for_csv_success = "Succeeded" ]]; do
		sleep 5
		check_for_csv_success=$(oc get csv -n "$projectName" --ignore-not-found | awk '$1 ~ /behavior-analytics-services-operator/ { print }' | awk -F' ' '{print $NF}')
		retries=$((retries + 1))
	done
	echo "$check_for_csv_success"
}

function createCerts() {

	cd mtls/
	cmdoutput=$(cfssl gencert -initca ca-csr.json | cfssljson -bare ca > /dev/null 2>&1)
	RETVAL=$?
	if [ RETVAL -gt 0 ]; then
		certsCreated=1
	else
		cmdoutput=$(cfssl gencert -ca=ca.pem -ca-key=ca-key.pem  -config=ca-config.json -profile=client client-csr.json | cfssljson -bare client > /dev/null 2>&1)
		RETVAL=$?
		if [ RETVAL -eq 0 ]; then
			certsCreated=0
	    else
			certsCreated=1
		fi
	fi
	echo $certsCreated
}

function checkDeploymentStatus() {

	retryCount=40
	retries=0
	check_for_deployment_status=$(oc get csv -n "$projectName" --ignore-not-found | awk '$1 ~ /behavior-analytics-services-operator/ { print }' | awk -F' ' '{print $NF}')
	until [[ $retries -eq $retryCount || $check_for_deployment_status = "Ready" ]]; do
		sleep 30
		check_for_deployment_status=$(oc get FullDeployment fulldeployment --output="jsonpath={.status.phase}")
		retries=$((retries + 1))
	done
	echo "$check_for_deployment_status"
}

function getGenerateAPIKey() {

	retryCount=10
	retries=0
	check_for_key=$(oc get secret bas-api-key --ignore-not-found)
	until [[ $retries -eq $retryCount || $check_for_key != "" ]]; do
		sleep 5
		check_for_key=$(oc get secret bas-api-key --ignore-not-found)
		retries=$((retries + 1))
	done
	if [[ $check_for_key != "" ]]; then
	   check_for_key=$(oc get secret bas-api-key --output="jsonpath={.data.apikey}" | base64 -d)
	fi
	echo "$check_for_key"
}