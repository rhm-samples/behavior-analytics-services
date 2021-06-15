#!/bin/bash

## This Script installs UDS operator using default values. 
source uds-script-functions.bash
source cr.properties

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

displayStepHeader 1 "Create a new project"
createProject

displayStepHeader 2 "Create an OperatorGroup object YAML file"

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

displayStepHeader 3 "Create the OperatorGroup object"

oc create -f uds-og.yaml &>>"${logFile}"

displayStepHeader 4 "Create a Subscription object YAML file to subscribe a Namespace"

cat <<EOF>uds-subscription.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: user-data-services-operator-certified
  namespace: "${projectName}"
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: user-data-services-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
  startingCSV: user-data-services-operator.v1.0.0
EOF


displayStepHeader 5 "Create Subscription object"

oc create -f uds-subscription.yaml &>>"${logFile}"


displayStepHeader 6 "Verify the Operator installation"
#There should be user-data-services-operator.v1.0.0.

check_for_csv_success=$(checkClusterServiceVersionSucceeded 2>&1)

if [[ "${check_for_csv_success}" == "Succeeded" ]]; then
	echoGreen "User Data Services Operator installed"
else
    echoRed "User Data Services Operator installation failed."
	exit 1;
fi

displayStepHeader 7 "Create a secret named database-credentials for PostgreSQL DB and grafana-credentials for Grafana"

oc create secret generic database-credentials --from-literal=db_username=${dbuser} --from-literal=db_password=${dbpassword} -n "${projectName}" &>>"${logFile}"

oc create secret generic consent-database-credentials --from-literal=consent_db_username=${consent_db_username} --from-literal=consent_db_password=${consent_db_password} -n "${projectName}" &>>"${logFile}"

oc create secret generic consent-ui-credentials --from-literal=consent_username=${consent_username} --from-literal=consent_password=${consent_password} -n "${projectName}" &>>"${logFile}"



displayStepHeader 8 "Create the yaml for AnalyticsProxy instance."


cat <<EOF>analytics-proxy.yaml
apiVersion: uds.ibm.com/v1
kind: AnalyticsProxy
metadata:
  name: analyticsproxydeployment
spec:
 allowed_domains: "*"
  db_archive:
    frequency: '@monthly'
    retention_age: 6
    persistent_storage:
      storage_class: "${storageClassArchive}"
      storage_size: "${storageSizeArchive}"
  airgappeddeployment:
    enabled: "${airgappedEnabled}"
    backup_deletion_frequency: '@daily'
    backup_retention_period: 7
  event_scheduler_frequency: "${eventSchedulerFrequency}"
  consent_scheduler_frequency: "${consent_scheduler_frequency}"
  ibmproxyurl: "${ibmproxyurl}"
  image_pull_secret: "${imagePullSecret}"
  postgres:
    storage_class: ${storageClassDB}
    storage_size: ${storageSizeDB}
  kafka:
    storage_class: "${storageClassKafka}"
    storage_size: "${storageSizeKafka}"
    zookeeper_storage_class: "${storageClassZookeeper}"
    zookeeper_storage_size: "${storageSizeZookeeper}"
  prometheus_scheduler_frequency: "${prometheusSchedulerFrequency}"
  prometheus_metrics: []
  env_type: "${envType}"
EOF

displayStepHeader 9 "Install the Deployment"

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

displayStepHeader 10 "Generate an API Key to use it for authentication"

cat <<EOF>api-key.yaml
apiVersion: uds.ibm.com/v1
kind: GenerateKey
metadata:
  name: uds-api-key
spec:
  image_pull_secret: uds-images-pull-secret
EOF


displayStepHeader 11 "Create the API Key"

oc create -f api-key.yaml
  
check_for_key=$(getGenerateAPIKey)

#Get the URLS
uds_endpoint_url=https://$(oc get routes uds-endpoint -n "${projectName}" |awk 'NR==2 {print $2}')
consent_endpoint_url=https://$(oc get routes consent-endpoint -n "${projectName}" |awk 'NR==2 {print $2}')

displayStepHeader 12 "Get the API key value and the URLs"
echo "===========API KEY=============="
echoYellow $check_for_key
echo "===========UDS Endpoint URL=============="
echoYellow $uds_endpoint_url
echo "===========Consent URL=============="
echoYellow $consent_endpoint_url

