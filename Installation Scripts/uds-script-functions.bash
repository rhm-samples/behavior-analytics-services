#!/bin/bash
logFile="uds-installation.log"

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

function echoLine() {
  echoYellow "----------------------------------------------------------------------------------------"
}

function echoYellow() {
  echo -e "${YELLOW}$1${NC}"
}

function displayStepHeader() {
  stepHeader=$(stepLog "$1" "$2")
  echoBlue "$stepHeader"
}

function stepLog() {
  echo -e "STEP $1/16: $2"
}

function displayStepHeaderTest() {
  stepHeader=$(stepLogTest "$1" "$2")
  echoBlue "$stepHeader"
}

function stepLogTest() {
  echo -e "STEP $1/5: $2"
}

function validatePropertiesfile(){
  file="./uds-cr.properties"
  if [ -f "$file" ]
  then
    echo "$file found."
    while IFS='=' read -r key value
    do
      key_name=$(echo $key | grep -v '^#')

      if [[ -z "$key_name" || "$key_name" == " " || $key_name == " " || $key_name == "http_proxy" || $key_name == "https_proxy" || $key_name == "no_proxy" || $key_name == "uds_host" || $key_name == "airgap_host"  ]];then
        continue
      fi
      if [[ -z "${!key_name}" || "${!key_name}" == "" || ${!key_name} == "" ]]; then
        echoRed "$key_name is empty"
            exit 1
      fi
    done < "$file"
  else
    echoRed "$file not found."
    exit 1
  fi
}


function checkPropertyValuesprompt(){
  echoBlue "Please check below Properties values and confirm to Continue with installation"
  file="./uds-cr.properties"

  while IFS= read -r line
  do
    key_name=$(echo $line | grep -v '^#')

    if [[ -z "$key_name" || "$key_name" == " " || $key_name == " " ]];then
      continue
    fi
    echo "$line"
  done < "$file"

  echoBlue "Are you sure, you want to Continue with Installation? [Y/n]: "
  read -r continueInstall </dev/tty
  if [[ ! $continueInstall || $continueInstall = *[^Yy] ]]; then
    echoRed "Aborting installation of User Data Services Operator"
    exit 0
  fi
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


function createProject(){
  existingns=$(oc get projects | grep -w "${projectName}" | awk '{print $1}')

  if [ "${existingns}" == "${projectName}" ]; then
    echoYellow "Project ${existingns} already exists, do you want to continue UDS operator installation in the existing project? [Y/n]: "
    read -r continueInstall </dev/tty
    if [[ ! $continueInstall || $continueInstall = *[^Yy] ]]; then
      echoRed "Aborting installation of UDS Operator, please set new value for the Project in the cr.properties file." 
      exit 0;
    fi
  else
    oc new-project "${projectName}" 1>>a 2>&1 "${logFile}"
      if [ $? -ne 0 ];then
	echoRed "FAILED: Project:${projectName} creation failed"
	exit 1
     fi
  fi
}

function checkClusterServiceVersionSucceeded() {

	retryCount=20
	retries=0
	check_for_csv_success=$(oc get csv -n "$projectName" --ignore-not-found | awk '$1 ~ /user-data-services-operator/ { print }' | awk -F' ' '{print $NF}')
	until [[ $retries -eq $retryCount || $check_for_csv_success = "Succeeded" ]]; do
		sleep 5
		check_for_csv_success=$(oc get csv -n "$projectName" --ignore-not-found | awk '$1 ~ /user-data-services-operator/ { print }' | awk -F' ' '{print $NF}')
		retries=$((retries + 1))
	done
	echo "$check_for_csv_success"
}

function checkDeploymentStatus() {

	retryCount=90
	retries=0
	check_for_deployment_status=$(oc get csv -n "$projectName" --ignore-not-found | awk '$1 ~ /user-data-services-operator/ { print }' | awk -F' ' '{print $NF}')
	until [[ $retries -eq $retryCount || $check_for_deployment_status = "Ready" ]]; do
		sleep 30
		check_for_deployment_status=$(oc get analyticsproxy.uds.ibm.com/analyticsproxydeployment --output="jsonpath={.status.phase}")
		retries=$((retries + 1))
	done
	echo "$check_for_deployment_status"
}

function getGenerateAPIKey() {

	retryCount=10
	retries=0
	check_for_key=$(oc get secret uds-api-key --ignore-not-found)
	until [[ $retries -eq $retryCount || $check_for_key != "" ]]; do
		sleep 5
		check_for_key=$(oc get secret uds-api-key --ignore-not-found)
		retries=$((retries + 1))
	done
	if [[ $check_for_key != "" ]]; then
	   check_for_key=$(oc get secret uds-api-key --output="jsonpath={.data.apikey}" | base64 -d)
	fi
	echo "$check_for_key"
}

function getSubmoduleAPIKey() {

	retryCount=10
	retries=0
	check_for_key=$(oc get secret submodule-service-key-secret --ignore-not-found)
	until [[ $retries -eq $retryCount || $check_for_key != "" ]]; do
		sleep 5
		check_for_key=$(oc get secret submodule-service-key-secret --ignore-not-found)
		retries=$((retries + 1))
	done
	if [[ $check_for_key != "" ]]; then
	   check_for_key=$(oc get secret submodule-service-key-secret --output="jsonpath={.data.apikey}" | base64 -d)
	fi
	echo "$check_for_key"
}
