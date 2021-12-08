
#!/bin/bash
source uds-script-functions.bash
check_for_key=$(getGenerateAPIKey)
uds_endpoint_url=https://$(oc get routes uds-endpoint -n "${projectName}" |awk 'NR==2 {print $2}')

displayStepHeaderTest 1 "Testing consumption API"
response=$(curl -fsS  -X POST "$uds_endpoint_url:443/v1/consumption" -H "accept: */*" -H "X-API-KEY: $check_for_key" -H "Content-Type: application/json" -d "{\"anonymousId\":\"GSE\",\"properties\":{\"frequency\":\"hourly\",\"productId\":\"Demo\",\"quantity\":100,\"unit\":\"AppPoints\",\"salesOrderNumber\":\"5\",\"chargePlanType\":0,\"planName\":\"test\",\"unitDescription\":\"gb\",\"productTitle\":\"test usage plan\",\"resultValue\":\"sample\"},\"timestamp\":\"2020-10-30T00:00:00.000Z\",\"type\":\"track\",\"userId\":\"00000\",\"writeKey\":\"<api-key>\"}")

if [[ $response != '' ]] ; then
    echoGreen "Consumption API Response : $response"
else 
    echoRed "Something went wrong...."
    exit 1;
fi

echoYellow "----------------------------------------------------------------------------------------"

displayStepHeaderTest 2 "Testing analytics API"
response=$(curl -fsS  -X POST "$uds_endpoint_url:443/v1/analytics" -H "accept: */*" -H "X-API-KEY: $check_for_key" -H "Content-Type: application/json" -d "{\"anonymousId\":\"GSE\",\"context\":{},\"event\":\"string\",\"groupId\":\"string\",\"integrations\":{},\"messageId\":\"string\",\"name\":\"string\",\"previousId\":\"string\",\"properties\":{},\"timestamp\":\"2020-01-01T00:00:00.000Z\",\"traits\":{},\"type\":\"track\",\"userId\":\"string\",\"writeKey\":\"<api-key>\"}")

if [[ $response != '' ]] ; then
    echoGreen "Analytics API Response : $response"
else 
    echoRed "Something went wrong...."
    exit 1;
fi
echoYellow "----------------------------------------------------------------------------------------"
echoGreen "UDS APIs tested successfully."