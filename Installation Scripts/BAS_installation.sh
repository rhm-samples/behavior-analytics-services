#!/bin/bash

## This Script installs BAS operator using default values. 
source bas-script-functions.bash
source cr.properties

requiredVersion="^.*4\.([0-9]{3,}|[3-9]?)?(\.[0-9]+.*)*$"
requiredServerVersion="^.*1\.([0-9]{16,}|[3-9]?)?(\.[0-9]+)*$"
ocpVersion="^\"4\.([0-9]{6,}|[6-9]?)?(\.[0-9]+.*)*$"
ocpVersion45="^\"4\.5\.[0-9]+.*$"
basVersion=v1.0.0

logFile="bas-installation.log"
touch "${logFile}"

validatePropertiesfile

checkPropertyValuesprompt
checkOCClientVersion
checkOpenshiftVersion

status=$(oc whoami 2>&1)
if [[ $? -gt 0 ]]; then
    echoRed "Login to OpenShift to continue BAS Operator installation."
        exit 1;
fi

displayStepHeader 1 "Create a new project"
createProject

displayStepHeader 2 "Create an OperatorGroup object YAML file"

cat <<EOF>bas-og.yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: bas-operator-group
  namespace: "${projectName}" 
spec: 
  targetNamespaces:
  - "${projectName}"
EOF

displayStepHeader 3 "Create the OperatorGroup object"

oc create -f bas-og.yaml &>>"${logFile}"

displayStepHeader 4 "Create a Subscription object YAML file to subscribe a Namespace"

cat <<EOF>bas-subscription.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: behavior-analytics-services-operator-certified
  namespace: "${projectName}"
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: behavior-analytics-services-operator-certified
  source: bas-111-test
  sourceNamespace: openshift-marketplace
  startingCSV: behavior-analytics-services-operator.v1.1.1
EOF


displayStepHeader 5 "Create Subscription object"

oc create -f bas-subscription.yaml &>>"${logFile}"


displayStepHeader 6 "Verify the Operator installation"
#There should be behavior-analytics-services-operator.v1.0.0.

check_for_csv_success=$(checkClusterServiceVersionSucceeded 2>&1)

if [[ "${check_for_csv_success}" == "Succeeded" ]]; then
	echoGreen "Behavior Analytics Services Operator installed"
else
    echoRed "Behavior Analytics Services Operator installation failed."
	exit 1;
fi

displayStepHeader 7 "Create a secret named database-credentials for PostgreSQL DB and grafana-credentials for Grafana"

oc create secret generic database-credentials --from-literal=db_username=${dbuser} --from-literal=db_password=${dbpassword} -n "${projectName}" &>>"${logFile}"

oc create secret generic grafana-credentials --from-literal=grafana_username=${grafanauser} --from-literal=grafana_password=${grafanapassword} -n "${projectName}" &>>"${logFile}"


displayStepHeader 8 "Create the yaml for AnalyticsProxy instance."


cat <<EOF>analytics-proxy.yaml
apiVersion: bas.ibm.com/v1
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
  airgapped:
    enabled: ${airgappedEnabled}
    backup_deletion_frequency: '@daily'
    backup_retention_period: 7
  event_scheduler_frequency: "${eventSchedulerFrequency}"
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
  env_type: "${envType}"
  proxy_settings:
    http_proxy: "${http_proxy}"
    https_proxy: "${https_proxy}"
    no_proxy: "${no_proxy}"
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
apiVersion: bas.ibm.com/v1
kind: GenerateKey
metadata:
  name: bas-api-key
spec:
  image_pull_secret: bas-images-pull-secret
EOF


displayStepHeader 11 "Create the API Key"

oc create -f api-key.yaml
  
check_for_key=$(getGenerateAPIKey)

#Get the URLS
bas_endpoint_url=https://$(oc get routes bas-endpoint -n "${projectName}" |awk 'NR==2 {print $2}')
grafana_dashboard_url=https://$(oc get routes grafana-route -n "${projectName}" |awk 'NR==2 {print $2}')


displayStepHeader 12 "Get the API key value and the URLs"
echo "===========API KEY=============="
echoYellow $check_for_key
echo "===========BAS Endpoint URL=============="
echoYellow $bas_endpoint_url
echo "===========Grafana URL=============="
echoYellow $grafana_dashboard_url

