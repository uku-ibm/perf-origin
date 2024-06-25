#!/bin/sh
prerequisite(){
       # file="./origin.properties"
       # while IFS='=' read -r key value; do
       #         echo "key: $key, value: $value"
       #         sed -i "s*$key*$value*g" JMeterScripts/CreateEdgeServer.jmx
       # done < "$file"
       # $JMETER_HOME/bin/jmeter.sh -n -t JMeterScripts/CreateEdgeServer.jmx -Jthreads=1
       echo "prerequisite"
}
prepare_jmeter_script()
{
        echo " prepare jmeter script "
        file="./origin.properties"
        while IFS='=' read -r key value; do
                echo "key: $key, value: $value"
                sed -i "s*$key*$value*g" JMeterScripts/"$workload".jmx
        done < "$file"
        #sed -i "s*PATH*$endpointpath*g" JMeterScripts/"$workload".jmx
        echo "Fetch auth, cookie, X-csrf-token"
        rm -f token.json
        curl -s -u ${TENANT_USERNAME}:${TENANT_PASSWORD} https://$CLOUD_NAME/enterprise/v1/user/token > token.json
        
        AUTH_TOKEN=`cat token.json | grep -oP '(?<="authtoken":")[^"]*'`
        COOKIE=`cat token.json | grep -oP '(?<="cookie":")[^"]*'`
        CSRF=`cat token.json | grep -oP '(?<="csrf":")[^"]*'`
        #https://originawsint2.int-aw-us1.webmethods-int.io/enterprise/v1/projects?limit=19&skip=0&q=PerformanceTest
        PROJECT_ID=$(curl -s -H "authtoken:$AUTH_TOKEN" -H "cookie:$COOKIE" -H "X-csrf-token:$CSRF" "https://$CLOUD_NAME/enterprise/v1/projects?limit=19&skip=0&q=$PROJECT_NAME" | grep -oP '(?<="ic_project_name":")[^"]*')
        if [ -z "$PROJECT_ID" ]; then
            echo "PROJECT_ID is empty or null"
        else
            echo "PROJECT_ID (Begin):$PROJECT_ID(end)"
        fi
        sleep 5s
        echo "Fetching AGENT_ID"
        AGENT_ID=$(curl -s -H "authtoken:$AUTH_TOKEN" -H "cookie:$COOKIE" -H "X-csrf-token:$CSRF" "https://$CLOUD_NAME/integration/rest/edge/runtimes?page=1&limit=19&searchKey=$REMOTE_EDGE_SERVER_NAME" | grep -oP '(?<="agentID":")[^"]*')
        echo "AGENT_ID: $AGENT_ID"
        if [ -z "$AGENT_ID" ]; then
            echo "AGENT_ID is empty or null"
        else
            echo "Fetching AGENT_ID again"
            AGENT_ID=$(curl -s -H "authtoken:$AUTH_TOKEN" -H "cookie:$COOKIE" -H "X-csrf-token:$CSRF" "https://$CLOUD_NAME/integration/rest/edge/runtimes?page=1&limit=19&searchKey=$REMOTE_EDGE_SERVER_NAME" | grep -oP '(?<="agentID":")[^"]*' | head -1)
            echo "AGENT_ID: $AGENT_ID"
            echo "AGENT_ID (Begin):$AGENT_ID(end)"
        fi
        
        echo "REQUEST 1"
        RESPONSE_OUTPUT=$(curl -s -X POST -H "Content-Type: application/json" -H "authtoken:$AUTH_TOKEN" -H "cookie:$COOKIE" -H "X-csrf-token:$CSRF" -d "{\"agentID\":\"default\",\"agentGroup\":\"Default\",\"apiEndPoint\":\"/scaffolding/agentManifest\",\"httpMethod\":\"POST\",\"input\":{\"agentId\":\"$AGENT_ID\",\"tags\":\"VaryingPayload\",\"services\":[{\"serviceName\":\"project.performancetest.integrations:VaryingPayload\"}]}}" "https://$CLOUD_NAME/integration/rest/edge/flow/admin-proxy")
        echo "REQUEST 1, RESPONSE: $RESPONSE_OUTPUT"
        
        echo "REQUEST 2"
        RESPONSE_OUTPUT=$(curl -s -X POST -H "Content-Type: application/json" -H "authtoken:$AUTH_TOKEN" -H "cookie:$COOKIE" -H "X-csrf-token:$CSRF" -d "{\"apiEndPoint\":\"/scaffolding/sync\",\"agentID\":\"$AGENT_ID\",\"agentGroup\":\"default\",\"httpMethod\":\"POST\",\"input\":{\"agentId\":\"$AGENT_ID\",\"enableConnections\":true}}" "https://$CLOUD_NAME/integration/rest/edge/flow/admin-proxy")
        echo "REQUEST 2, RESPONSE: $RESPONSE_OUTPUT"
        
        echo "REQUEST 3"
        RESPONSE_OUTPUT=$(curl -s -X POST -H "Content-Type: application/json" -H "authtoken:$AUTH_TOKEN" -H "cookie:$COOKIE" -H "X-csrf-token:$CSRF" -d "{\"apiEndPoint\":\"/package/PerformanceTestProject\",\"agentID\":\"default\",\"agentGroup\":\"default\",\"httpMethod\":\"GET\"}" "https://$CLOUD_NAME/integration/rest/edge/flow/admin-proxy")
        echo "REQUEST 3, RESPONSE: $RESPONSE_OUTPUT"
        
        echo "REQUEST 4"
        RESPONSE_OUTPUT=$(curl -s -X POST -H "Content-Type: application/json" -H "authtoken:$AUTH_TOKEN" -H "cookie:$COOKIE" -H "X-csrf-token:$CSRF" -d "{\"apiEndPoint\":\"/package/PerformanceTestProject\",\"agentID\":\"$AGENT_ID\",\"agentGroup\":\"default\",\"httpMethod\":\"GET\"}" "https://$CLOUD_NAME/integration/rest/edge/flow/admin-proxy")
        echo "REQUEST 4, RESPONSE: $RESPONSE_OUTPUT"
        
        echo "AUTH_TOKEN-----$AUTH_TOKEN"
        echo "COOKIE-----$COOKIE"
        echo "CSRF-----$CSRF"
        sed -i "s*AGENT_ID*$AGENT_ID*g" JMeterScripts/"$workload".jmx
        sed -i "s*PROJECT_ID*$PROJECT_ID*g" JMeterScripts/"$workload".jmx
        sed -i "s*AUTH_TOKEN*$AUTH_TOKEN*g" JMeterScripts/"$workload".jmx
        sed -i "s*COOKIE*$COOKIE*g" JMeterScripts/"$workload".jmx
        sed -i "s*CSRF*$CSRF*g" JMeterScripts/"$workload".jmx
}

execute_jmeter_script()
{
        echo " execute jmeter script $testcase SCRIPTNAME=$2 THREADS=$3 DURATION=$4 RESULTFILE=$1"
        $JMETER_HOME/bin/jmeter.sh -n -t JMeterScripts/$2.jmx -Jthreads=$3 -Jduration=$4 -l TEMP_DIRECTORY/$1.jtl
        java -jar $JMETER_HOME/lib/cmdrunner-2.2.jar --tool Reporter --generate-csv TEMP_DIRECTORY/$1.csv --input-jtl TEMP_DIRECTORY/$1.jtl --plugin-type SynthesisReport
        cat TEMP_DIRECTORY/$testcase.csv
        rm -f TEMP_DIRECTORY/$1.jtl
        java -DWORKLOAD_NAME=$1 -DTEMP_DIRECTORY=$5/ -cp bpt_utils.jar perf.bpt.util.CompareBaseline
}

source ./origin.properties # CLOUD_NAME, REMOTE_EDGE_SERVER_NAME will be picked up as environment variables from ./origin.properties file
echo "CLOUD_NAME: $CLOUD_NAME"
echo "REMOTE_EDGE_SERVER_NAME: $REMOTE_EDGE_SERVER_NAME"
File="Tests/Benchmark_testcase_All.csv"
JMETER_HOME=/home/ec2-user/apache-jmeter-5.5
TEMP_DIRECTORY=$1
TENANT_USERNAME=$2
TENANT_PASSWORD=$3
Lines=$(cat $File)
for Line in $Lines
do
        echo "Test: $Line"
        variable=$Line
        if [[ $variable == *"testcase"* ]]; then
                continue
        fi
        IFS=', ' read -r -a array <<< "$variable"
        testcase=${array[0]}
        concurrentusers=${array[1]}
        duration=${array[2]}
        endpointpath=${array[3]}
        workload="$testcase"_"$concurrentusers"
        echo "workload: $workload"
        cp JMeterScripts/$testcase.jmx JMeterScripts/$workload.jmx
        prepare_jmeter_script $workload
        execute_jmeter_script $testcase $workload $concurrentusers $duration $TEMP_DIRECTORY
done
