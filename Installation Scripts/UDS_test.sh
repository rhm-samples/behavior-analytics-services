
#!/bin/bash
. ./uds-script-functions.bash
requiredVersion="^\"4\.([0-9]{6,}|[6-9]|[1-9][0-9]?)?(\.[0-9]+.*)*$"
requiredServerVersion="^.*1\.([0-9]{16,}|[3-9]?)?(\.[0-9]+)*$"

while getopts n:k:h--help: option; do
  case "${option}" in
    n) NS=${OPTARG};;
    k) SK=${OPTARG};;
    h|--help)
      echo "
Options:
  -n: Namespace where UDS is installed
  -k: Segment Key

Examples:
  # To get help:
  ./UDs_test.sh -h

  # To test UDS APIs in 'uds-test' namespace:
  ./UDs_test.sh -n uds-test
  
  # To test UDS APIs in 'uds-test' namespace: and send events to segment
  ./UDs_test.sh -n uds-test -k segment_key
  "
      exit 0
      ;;
  esac
done

checkOCClientVersion

status=$(oc whoami 2>&1)
if [[ $? -gt 0 ]]; then
    echoRed "Login to OpenShift to continue UDS Operator installation."
        exit 1;
fi

if [ -z "$SK" ]; then
      echoRed "It looks like you haven't set the Segment Key to test UDS APIs"
  echoBlue "Check Options by using -h or --help"
  exit 1;
fi

if [ ! -z "$NS" ]; then
    projectName="${NS}"
    oc project "${projectName}"
else
  echoRed "It looks like you haven't set the namespace to test UDS APIs"
  echoBlue "Check Options by using -h or --help"
  exit 1;
fi

flag_uds=true
flag_sm=true
check_for_key=$(getGenerateAPIKey)
uds_endpoint_url=$(oc get routes uds-endpoint -n "${projectName}" |awk 'NR==2 {print $2}')

if [[ -z "$check_for_key" ]];then
      echoRed "API Key not found, please generate API key..."
      exit 1;
fi

if [[ -z "$uds_endpoint_url" || "$uds_endpoint_url" == " " ]];then
      echoRed "Something went wrong...."
      exit 1;
fi


echoLine
echoGreen "UDS Endpoint Exists"
uds_endpoint_url=https://"$uds_endpoint_url"

echoBlue "Testing Event APIs"
echoLine

displayStepHeaderTest 1 "Testing Consumption API"
response=$(curl -fsS  -X POST "$uds_endpoint_url:443/v1/consumption" \
-H "accept: */*" -H "X-API-KEY: $check_for_key" -H "Content-Type: application/json" \
-d "{\"anonymousId\":\"GSE\",\"properties\":{\"frequency\":\"hourly\",\"productId\":\"Demo\",\"quantity\":100,\"unit\":\"AppPoints\",\"salesOrderNumber\":\"5\",\"chargePlanType\":0,\"planName\":\"test\",\"unitDescription\":\"gb\",\"productTitle\":\"test usage plan\",\"resultValue\":\"sample\"},\"timestamp\":\"2020-10-30T00:00:00.000Z\",\"type\":\"track\",\"userId\":\"00000\",\"writeKey\":\"${SK}\"}")

if [[ $response != '' ]] ; then
    echoGreen "Consumption API Response : $response"
else 
    echoRed "Something went wrong in Consumption endpoint...."
    flag_uds=false
fi

echoLine

displayStepHeaderTest 2 "Testing analytics API"
response=$(curl -fsS  -X POST "$uds_endpoint_url:443/v1/analytics/v1/track" \
-H "accept: */*" -H "X-API-KEY: $check_for_key" -H "Content-Type: application/json" \
-d "{\"anonymousId\":\"GSE\",\"context\":{},\"event\":\"string\",\"groupId\":\"string\",\"integrations\":{},\"messageId\":\"string\",\"name\":\"string\",\"previousId\":\"string\",\"properties\":{},\"timestamp\":\"2020-01-01T00:00:00.000Z\",\"traits\":{},\"type\":\"track\",\"userId\":\"string\",\"writeKey\":\"${SK}\"}")

if [[ $response != '' ]] ; then
    echoGreen "Analytics API Response : $response"
else 
    echoRed "Something went wrong in Analytics endpoint...."
    flag_uds=false
fi

echoLine

displayStepHeaderTest 3 "Testing Onboarding API"
response=$(curl -fsS --location --request POST "$uds_endpoint_url:443/v1/onboarding/eventserver/event/postEvent" \
--header "X-API-KEY: $check_for_key" \
--header 'Content-Type: text/plain' \
-d '{"_static":true,"Wm-Client-Timestamp":1648106175843} {"time":1648106175592,"type":"open","data":{"type":"player","pInit":{"type":1}},"sId":"804a9db9-bebc-4a08-9fbf-82eefcb7c2b7","wm":{"uId":"23176470db1e4b2caa020d94b3364854","euId":"48f2a42f-16bc-409c-a2ab-aa766f787700","euIdSource":"Cache","permId":-1,"env":3,"interactionGuid":"4bc60ea4-3486-468d-afcc-327b1fbf4d5e","platform":1,"cseuId":"9b1502bb-34b1-4a32-b291-f6f487cad344"},"env":{"browser":{"name":"Chrome","version":"99.0.4844.74"},"os":{"name":"Windows","version":"10"},"screen":{"height":720,"width":1280},"mobile":false,"timezone":-330},"ctx":{"location":{"protocol":"http:","hostname":"localhost","port":"3000","pathname":"/"},"isIframe":false,"visitId":"e55d8548d3854f4e9ea4bdf902e75976","title":"Reference App"},"version":{"lib":"20210528-103929-f9c74106","pe":"5.0.2"}}')

if [[ $response != '' ]] ; then
    echoGreen "Onboarding API Response : $response"
else
    echoRed "Something went wrong in Onboarding endpoint...."
    flag_uds=false
fi

echoLine
if [ "$flag_uds" = true ] ; then
    echoGreen "Event APIs tested successfully."
    oc create job --from=cronjob/event-scheduler event-scheduler-test
    #oc delete job event-scheduler-test
else
    echoRed "Event API(s) failing."
fi

echoLine
############ SUBMODULE APIS
submodule_endpoint_url=$(oc get routes submodule-endpoint -n "${projectName}" |awk 'NR==2 {print $2}')
if [[ -z "$submodule_endpoint_url" || "$submodule_endpoint_url" == " " ]];then
      echoRed "Something went wrong...."
      exit 1;
fi

echoLine
echoGreen "Submodule Endpoit Exists"
submodule_endpoint_url=https://"$submodule_endpoint_url"

echoBlue "Testing Submodule APIs"


echoLine

displayStepHeaderTest 4 "Testing Consent API"
response=$(curl -fsS --location --request POST "$submodule_endpoint_url/cm/2/consents" \
--header "X-dpcm-apikey: $check_for_key" \
--header 'Content-Type: application/json' \
--header "X-dpcm-addsystemidentifier: true" \
-d '{
	"state":"1",
	"purpose_id":"1",
	"consenter_id":"testscriptid_11",
	"end_date": "2055-01-01T00:00:00.000Z",
	"access_type_id": 1,
	"attributes":[
        {
          "name":"EmailAddress",
          "value":"johndoe@dummy.com"
        },
        {
          "name":"ProductName",
          "value":"Test Script"
        }
     ]
}')

if [[ $response != '' ]] ; then
    echoGreen "Consent API Response : $response"
else
    echoRed "Something went wrong in Consent endpoint...."
    flag_sm=false
fi

echoLine
displayStepHeaderTest 5 "Testing Consent Search API"

response=$(curl -fsS --location --request POST "$submodule_endpoint_url/cm/2/search/consents" \
--header "X-dpcm-apikey: $check_for_key" \
--header 'Content-Type: application/json' \
-d '{
	"consenter_id": "testscriptid_11"
}')

if [[ $response != '' ]] ; then
    echoGreen "Consent Search API Response : $response"
else
    echoRed "Something went wrong in Consent Search enpoint...."
    flag_sm=false
fi
echoLine
if [ "$flag_sm" = true ] ; then
    echoGreen "Submodule APIs tested successfully."
    oc create job --from=cronjob/submodule-scheduler submodule-scheduler-test
    #oc delete job submodule-scheduler-test
else    
    echoRed "Submodule API(s) failing"
fi
echoLine
