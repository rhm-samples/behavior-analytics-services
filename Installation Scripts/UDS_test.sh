
#!/bin/bash
source uds-script-functions.bash

while getopts n:u:t:h--help: option; do
  case "${option}" in
    n) NS=${OPTARG};;
    h|--help)
      echo "
Options:
  -n: Namespace where UDS is installed

Examples:
  # To get help:
  ./UDs_test.sh -h

  # To test UDS APIs in 'uds-test' namespace:
  ./UDs_test.sh -n uds-test
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
if [[ -z "$uds_endpoint_url" || "$uds_endpoint_url" == " " ]];then
      echoRed "Something went wrong...."
      exit 1;
fi

uds_endpoint_url=https://"$uds_endpoint_url"

echoLine
echoBlue "Testing Event APIs"
echoLine

displayStepHeaderTest 1 "Testing Consumption API"
response=$(curl -fsS  -X POST "$uds_endpoint_url:443/v1/consumption" \
-H "accept: */*" -H "X-API-KEY: $check_for_key" -H "Content-Type: application/json" \
-d "{\"anonymousId\":\"GSE\",\"properties\":{\"frequency\":\"hourly\",\"productId\":\"Demo\",\"quantity\":100,\"unit\":\"AppPoints\",\"salesOrderNumber\":\"5\",\"chargePlanType\":0,\"planName\":\"test\",\"unitDescription\":\"gb\",\"productTitle\":\"test usage plan\",\"resultValue\":\"sample\"},\"timestamp\":\"2020-10-30T00:00:00.000Z\",\"type\":\"track\",\"userId\":\"00000\",\"writeKey\":\"<api-key>\"}")

if [[ $response != '' ]] ; then
    echoGreen "Consumption API Response : $response"
else 
    echoRed "Something went wrong in Consumption endpoint...."
    flag_uds=false
fi

echoLine

displayStepHeaderTest 2 "Testing analytics API"
response=$(curl -fsS  -X POST "$uds_endpoint_url:443/v1/analytics" \
-H "accept: */*" -H "X-API-KEY: $check_for_key" -H "Content-Type: application/json" \
-d "{\"anonymousId\":\"GSE\",\"context\":{},\"event\":\"string\",\"groupId\":\"string\",\"integrations\":{},\"messageId\":\"string\",\"name\":\"string\",\"previousId\":\"string\",\"properties\":{},\"timestamp\":\"2020-01-01T00:00:00.000Z\",\"traits\":{},\"type\":\"track\",\"userId\":\"string\",\"writeKey\":\"<api-key>\"}")

if [[ $response != '' ]] ; then
    echoGreen "Analytics API Response : $response"
else 
    echoRed "Something went wrong in Analytics endpoint...."
    flag_uds=false
fi

echoLine

displayStepHeaderTest 3 "Testing Onboarding API"
response=$(curl -fsS --location --request POST "$uds_endpoint_url:443/v1/onboarding" \
--header "X-API-KEY: $check_for_key" \
--header 'Content-Type: application/json' \
--header 'Cookie: ae218ec24d58bcd4332d36922e4fc282=5d1791173c068ebf565a6f3226d1051b' \
-d '{"_static":true,"Wm-Client-Timestamp":1598454659765}
{"time":1598454659500,"type":"play","data":{"type":"bizFlowStep","oId":5515782,"aoId":5515782,"oName":"WalkMe Menu","oType":0,"owId":569837,"owName":"Reference App Tour","owType":"bizFlow","total":51,"pId":"1598454639937-569837-548c5973-5af9-4bb6-be96-a416ac2a6c82","status":6},"sId":"a7a7284a-3096-4d5d-b66b-524a6780c8ef","wm":{"uId":"c5d0ab74c254452f8ef7bd4156bbee40","euId":"7831cc97-9d84-40a7-89ef-4985a68f1d9e","euIdSource":"Identifier","permId":-1,"env":3,"interactionGuid":"7a668482-d9e2-4e6d-91f6-4e50c33ebc14","platform":1,"cseuId":"483d8978-181c-4036-964e-7a59167f1629"},"env":{"browser":{"name":"Firefox","version":"77.0"},"os":{"name":"Windows"},"mobile":false,"timezone":-330},"ctx":{"location":{"protocol":"https:","hostname":"localhost.ibm.com","pathname":"/catalog"},"isIframe":false,"visitId":"68c9d1a917c94009a27effc3348ebaf8","title":"Reference App","referrer":"https://localhost.ibm.com/"},"visions":{"sId":"a7a7284a-3096-4d5d-b66b-524a6780c8ef"},"version":{"lib":"20200812-160452-a9fb741f","pe":"5.0.2"}}')

if [[ $response != '' ]] ; then
    echoGreen "Onboarding API Response : $response"
else
    echoRed "Something went wrong in Onboarding endpoint...."
    flag_uds=false
fi

echoLine
if [ "$flag_uds" = true ] ; then
    echoGreen "Event APIs tested successfully."
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

submodule_endpoint_url=https://"$submodule_endpoint_url"

echoBlue "Testing Submodule APIs"


echoLine

displayStepHeaderTest 4 "Testing Consent API"
response=$(curl -fsS --location --request POST "$submodule_endpoint_url/cm/2/consents" \
--header "X-dpcm-apikey: $check_for_key" \
--header 'Content-Type: application/json' \
--header 'Cookie: 7f9746c7c25e68415b39dc77b965c509=3f22952074ead4ec51effb683010ad1e' \
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
--header 'Cookie: 7f9746c7c25e68415b39dc77b965c509=3f22952074ead4ec51effb683010ad1e' \
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
else    
    echoRed "Submodule API(s) failing"
fi
echoLine
