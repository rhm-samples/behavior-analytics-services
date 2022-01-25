#!/bin/bash

source script-functions.bash

requiredVersion="^.*4\.([0-9]{3,}|[3-9]?)?(\.[0-9]+.*)*$"
requiredServerVersion="^.*1\.([0-9]{16,}|[3-9]?)?(\.[0-9]+)*$"
COMPLETED="Completed"

ns=""

option="${1}" 
case ${option} in 
    --ns)
        ns="${2}"
        ;;
    *)
       echo "`basename ${0}`: usage: [--ns namespace]"
       exit 1;
       ;;
esac

displayStepHeader 1 "Checking oc login"
status=$(oc whoami 2>&1)
if [[ $? -gt 0 ]]; then
    echoRed "Login to OpenShift to continue."
        exit 1;
fi


displayStepHeader 2 "Validate a namespace"

proj=$(oc project "$ns" || grep `"Using project"`)

if [ ! -z "$proj" -a "$proj" != " " ]; then
    echoGreen "$proj"
else 
    echoRed "$proj"
    exit 1
fi

displayStepHeader 3 "Deleting existing mTLS secret"

oc delete secret mtls-proxy-secret;

displayStepHeader 4 "Creating mTLS update job yaml"

temp_artifact_job=$(mktemp)
cat <<EOF>> $temp_artifact_job
kind: Job
apiVersion: batch/v1
metadata:
  name: update-mtls
  labels:
    app: update-mtls
    app.kubernetes.io/name: "update-mtls"
spec:
  template:
    metadata:
      labels:
        app: update-mtls
        app.kubernetes.io/name: "update-mtls"
    spec:
      restartPolicy: Never
      securityContext: {}
      serviceAccountName: behavior-analytics-services-operator
      containers:
        - resources: {}
          name: oc-command-line
          command:
            - /bin/sh
            - '-c'
            - >
              echo "Creating new mtls secret";
              oc apply -f /mtls/update-mtls-secret.yaml;
          imagePullPolicy: Always         
          image: registry.connect.redhat.com/ibm-edge/growth-stack-base:mtls-proxy
EOF

displayStepHeader 5 "Applying mtls update job yaml"
oc apply -n "${ns}" -f "${temp_artifact_job}"

echoYellow "Job will take 1-2 mins. to execute."
sleep  10 
jobstaus=$(oc get pods |grep  update-mtls | awk '{print $3}')

retryCount=6
retries=0
until [[ $retries -eq $retryCount || $jobstaus = "Completed" ]]; do
		sleep 10
		jobstaus=$(oc get pods |grep  update-mtls | awk '{print $3}')
		retries=$((retries + 1))
	done


if [ "$jobstaus" = "$COMPLETED" ]; then
    echoGreen "Job Completed"
else
    echoRed "Job Failed, status: $jobstaus"
fi

displayStepHeader 6 "Restarting simple-reverse-proxy pod"
revpo=$(oc get pods | grep "simple-reverse-proxy" | awk '{print $1}')

for i in "${revpo[@]}"
do
  oc delete pod $i
done

displayStepHeader 7 "Performing Cleanup"

echoYellow "Deleting update-mtls job"
oc delete job update-mtls

rm $temp_artifact_job
