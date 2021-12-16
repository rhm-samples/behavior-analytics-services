#!/bin/bash

## This Script installs UDS operator using default values. 
source uds-script-functions.bash
source uds-cr.properties

requiredVersion="^.*4\.([0-9]{3,}|[3-9]?)?(\.[0-9]+.*)*$"
requiredServerVersion="^.*1\.([0-9]{16,}|[3-9]?)?(\.[0-9]+)*$"


logFile="uds-installation.log"
touch "${logFile}"

validatePropertiesfile

checkPropertyValuesprompt
checkOCClientVersion

status=$(oc whoami 2>&1)
if [[ $? -gt 0 ]]; then
    echoRed "Login to OpenShift to continue UDS Operator installation."
        exit 1;
fi

displayStepHeader 1 "Create a CatalogSource object YAML file"
cat <<EOF>ibm-operator-catalog.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-operator-catalog
  image: icr.io/cpopen/ibm-operator-catalog
  publisher: IBM Content
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

displayStepHeader 2 "Create the CatalogSource object"

oc create -f ibm-operator-catalog.yaml &>>"${logFile}"

displayStepHeader 3 "Create a new project"
createProject

displayStepHeader 4 "Create an OperatorGroup object YAML file"

cat <<EOF>uds-og.yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: uds-operator-group
  namespace: "${projectName}" 
spec: 
  targetNamespaces:
  - "${projectName}"
EOF

displayStepHeader 5 "Create the OperatorGroup object"

oc create -f uds-og.yaml &>>"${logFile}"

displayStepHeader 6 "Create a Subscription object YAML file to subscribe a Namespace"

cat <<EOF>cs-subscription.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-common-service-operator
  namespace: "${projectName}"
spec:
  channel: v3
  installPlanApproval: Automatic
  name: ibm-common-service-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
  startingCSV: ibm-common-service-operator.v3.14.0
EOF


displayStepHeader 7 "Create Subscription object"

oc create -f cs-subscription.yaml &>>"${logFile}"


displayStepHeader 8 "Verify the Operator installation"
echoBlue "Waiting to deploy UDS"
sleep 300

#check_for_deployment_status=$(checkDeploymentStatusOperandReg 2>&1)
retryCount=50
  retries=0
  check_for_deployment_status=$(oc get csv -n "$projectName" --ignore-not-found | awk '$1 ~ /operand-deployment-lifecycle-manager/ { print }' | awk -F' ' '{print $NF}')
  until [[ $retries -eq $retryCount ]]; do
    sleep 5
    if [[ "$check_for_deployment_status" == "Ready for Deployment" || "$check_for_deployment_status" == "Running" ]]; then
      break
    fi
    check_for_deployment_status=$(oc get OperandRegistries common-service --output="jsonpath={.status.phase}")
    retries=$((retries + 1))
  done

if [[ "$check_for_deployment_status" == "Ready for Deployment" || "$check_for_deployment_status" == "Running" ]]; then
	echoGreen "Ready for UDS Deployment"
else
    echoRed "Not Ready for UDS Deployment"
	exit 1;
fi
displayStepHeader 9 "Create UDS Operand request YAML"

cat <<EOF>uds-or.yaml
apiVersion: operator.ibm.com/v1alpha1
kind: OperandRequest
metadata:
  name: ibm-user-data-services
  labels:
    app.kubernetes.io/instance: operand-deployment-lifecycle-manager
    app.kubernetes.io/managed-by: operand-deployment-lifecycle-manager
    app.kubernetes.io/name: operand-deployment-lifecycle-manager
  namespace: ibm-common-services
spec:
  requests:
    - operands:
        - name: ibm-user-data-services-operator
      registry: common-service
EOF

displayStepHeader 10 "Create UDS Operand request"

oc create -f uds-or.yaml &>>"${logFile}"

displayStepHeader 11 "Verify the Operator installation"
#There should be user-data-services-operator.v2.0.2.
check_for_csv_success=$(checkClusterServiceVersionSucceeded 2>&1)
if [[ "${check_for_csv_success}" == "Succeeded" ]]; then
	echoGreen "User Data Services Operator installed"
else
    echoRed "User Data Services Operator installation failed."
	exit 1;
fi

displayStepHeader 12 "Create the yaml for AnalyticsProxy instance."


cat <<EOF>analytics-proxy.yaml
apiVersion: uds.ibm.com/v1
kind: AnalyticsProxy
metadata:
  name: analyticsproxydeployment
spec:
  license:
    accept: true 
  allowed_domains: "*"
  db_archive:
    persistent_storage:
      storage_size: "${storageSizeArchive}"
  airgappeddeployment:
    enabled: ${airgappedEnabled}
  event_scheduler_frequency: "${eventSchedulerFrequency}"
  ibmproxyurl: "${ibmproxyurl}"
  storage_class: ${storageClass}
  postgres:
    storage_size: ${storageSizeDB}
    backup_type: ${postgresBackupType}
    backup_frequency: '${postgresBackupFre}'
  kafka:
    storage_size: "${storageSizeKafka}"
    zookeeper_storage_size: "${storageSizeZookeeper}"
  env_type: "${envType}"
  tls:
    uds_host: "${uds_host}"
    airgap_host: "${airgap_host}"  
  proxy_settings:
    http_proxy: "${http_proxy}"
    https_proxy: "${https_proxy}"
    no_proxy: "${no_proxy}" 
EOF

displayStepHeader 13 "Install the Deployment"

oc create -f analytics-proxy.yaml &>>"${logFile}"

#Sleep for 5 mins
sleep 120

check_for_deployment_status=$(checkDeploymentStatus 2>&1)
if [[ "${check_for_deployment_status}" == "Ready" ]]; then
	echoGreen "Analytics Proxy Deployment setup ready"
else
    echoRed "Analytics Proxy Deployment setup failed."
	exit 1;
fi


displayStepHeader 14 "Generate an API Key to use it for authentication"

cat <<EOF>api-key.yaml
apiVersion: uds.ibm.com/v1
kind: GenerateKey
metadata:
  name: uds-api-key
spec:
  image_pull_secret: uds-images-pull-secret
EOF


displayStepHeader 15 "Create the API Key"

oc create -f api-key.yaml
  
check_for_key=$(getGenerateAPIKey)

#Get the URLS
uds_endpoint_url=https://$(oc get routes uds-endpoint -n "${projectName}" |awk 'NR==2 {print $2}')

displayStepHeader 16 "Get the API key value and the URLs"
echo "===========API KEY=============="
echoYellow $check_for_key
echo "===========UDS Endpoint URL=============="
echoYellow $uds_endpoint_url


