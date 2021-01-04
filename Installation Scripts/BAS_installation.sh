#!/bin/bash

## This Script installs BAS operator using default values. 
source bas-script-functions.bash
source cr.properties

requiredVersion="^.*4\.([0-9]{3,}|[3-9]?)?(\.[0-9]+.*)*$"
requiredServerVersion="^.*1\.([0-9]{16,}|[3-9]?)?(\.[0-9]+)*$"


logFile="bas-installation.log"
touch "${logFile}"

validatePropertiesfile

checkPropertyValuesprompt
checkOCClientVersion

status=$(oc whoami 2>&1)
if [[ $? -gt 0 ]]; then
    echoRed "Login to OpenShift to continue BAS Operator installation."
        exit 1;
fi

displayStepHeader 1 "Create a new project"

oc new-project "${projectName}" &>>"${logFile}"

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
  name: behavior-analytics-services-operator-migrated
  namespace: "${projectName}"
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: behavior-analytics-services-operator-migrated
  source: bas-operator
  sourceNamespace: openshift-marketplace
  startingCSV: behavior-analytics-services-operator.v1.0.0
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


displayStepHeader 8 "Create the key and cert for mtls secret"


cd mtls/
cmdoutput=$(cfssl gencert -initca ca-csr.json | cfssljson -bare ca > /dev/null 2>&1)
RETVAL=$?

if [[ RETVAL -gt 0 ]]; then
	certsCreated=1
else
	cmdoutput=$(cfssl gencert -ca=ca.pem -ca-key=ca-key.pem  -config=ca-config.json -profile=client client-csr.json | cfssljson -bare client > /dev/null 2>&1)
	RETVAL=$?
	if [[ RETVAL -eq 0 ]]; then
		certsCreated=0
    else
		certsCreated=1
	fi
fi
echo $certsCreated
if [[ "${certsCreated}" -eq 0 ]]; then
	echoGreen "mtls Key and Certificate created successfully"
else
    echoRed "Failed to create Key and Certificate"
	exit 1;
fi

cd ..

displayStepHeader 9 "Create a secret named mtls-proxy-secret which has the client key and certificate to connect to IBM Proxy service."
oc create secret tls mtls-proxy-secret --key ~/mtls/client-key.pem --cert ~/mtls/client.pem -n "${projectName}" &>> "${logFile}"

displayStepHeader 10 "Create the yaml for FullDeployment instance."


cat <<EOF>full-deployment.yaml
apiVersion: bas.ibm.com/v1
kind: FullDeployment
metadata:
  name: fulldeployment
spec:
  db_archive:
    frequency: '@monthly'
    retention_age: 6
    persistent_storage:
      storage_class: "${storageClassArchive}"
      storage_size: "${storageSizeArchive}"
  airgapped:
    enabled: "${airgappedEnabled}"
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
  prometheus_scheduler_frequency: "${prometheusSchedulerFrequency}"
  env_type: "${envType}"
EOF

displayStepHeader 11 "Install the Deployment"

oc create -f full-deployment.yaml &>>"${logFile}"

#Sleep for 5 mins
sleep 120

check_for_deployment_status=$(checkDeploymentStatus 2>&1)
if [[ "${check_for_deployment_status}" == "Ready" ]]; then
	echoGreen "FullDeployment setup ready"
else
    echoRed "FullDeployment setup failed."
	exit 1;
fi

displayStepHeader 12 "Generate an API Key to use it for authentication"

cat <<EOF>api-key.yaml
apiVersion: bas.ibm.com/v1
kind: GenerateKey
metadata:
  name: bas-api-key
spec:
  image_pull_secret: bas-images-pull-secret
EOF


displayStepHeader 13 "Create the API Key"

oc create -f api-key.yaml
  
check_for_key=$(getGenerateAPIKey)

#Get the URLS
bas_endpoint_url=https://$(oc get routes bas-endpoint -n "${projectName}" |awk 'NR==2 {print $2}')
grafana_dashboard_url=https://$(oc get routes grafana-route -n "${projectName}" |awk 'NR==2 {print $2}')


displayStepHeader 14 "Get the API key value and the URLs"
echo "===========API KEY=============="
echoYellow $check_for_key
echo "===========BAS Endpoint URL=============="
echoYellow $bas_endpoint_url
echo "===========Grafana URL=============="
echoYellow $grafana_dashboard_url

displayStepHeader 15 "Share the ~/mtls/client-key.pem and ~/mtls/cleint.pem with edge@ibm.com"
