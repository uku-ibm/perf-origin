#!/bin/bash
pull_edge_runtime_image(){
    docker pull iregistry.eur.ad.sag/aim/msr-edge-runtime:int
    IMAGE=iregistry.eur.ad.sag/aim/msr-edge-runtime:int
    date=`date +"%d-%m-%Y"`
    docker save -o $CURRENT_DIRECTORY/msr-edge-runtime-$date.tar $IMAGE
    echo "Saved $IMAGE to $CURRENT_DIRECTORY/msr-edge-runtime-$date.tar"
}

load_edge_runtime_image(){
    date=`date +"%d-%m-%Y"`
    docker load -i $CURRENT_DIRECTORY/msr-edge-runtime-$date.tar
    
    # TO CHANGE THE TAG OF THE DOCKER IMAGE
    #docker image tag 5f3c58976aec iregistry.eur.ad.sag/aim/msr-edge-runtime:int
}

delete_existing_edge_runtime_from_tenant(){
    echo "Search for perftest edge server from the tenant"
    response=$(curl -s -H "authtoken:$AUTH_TOKEN" -H "cookie:$COOKIE" -H "X-csrf-token:$CSRF" "https://$CLOUD_NAME/integration/rest/edge/runtimes?page=1&limit=19&searchKey=$REMOTE_EDGE_SERVER_NAME")
    echo "RESPONSE: $response"
    if [ -z "$response" ]; then
        echo "The response is empty or null"
    else
        agentID=$(echo "$response" | grep -oP '(?<="agentID":")[^"]*')
        if [ -z "$agentID" ]; then
            echo "AgentID is empty or null"
        else
            echo "The agent ID: $agentID"
            echo "Deleting the perftest edge server from the tenant with agent ID: $agentID"
            response=""
            echo "curl -s -X DELETE -H "authtoken:$AUTH_TOKEN""
            response=$(curl -s -X DELETE -H "authtoken:$AUTH_TOKEN" -H "cookie:$COOKIE" -H "X-csrf-token:$CSRF" "https://$CLOUD_NAME/integration/rest/edge/runtimes/$agentID/deregister?force=true")
            echo "RESPONE: $response"
            # stop all running containers
            echo '####################################################'
            echo 'Stopping running containers (if available)...'
            echo '####################################################'
            docker stop $(docker ps -aq)

            # remove all stopped containers
            echo '####################################################'
            echo 'Removing containers ..'
            echo '####################################################'
            docker rm $(docker ps -aq)
        fi
    fi


}
verify_edge_runtime_on_tenant_runtime_dashboard(){
    echo "verify edge runtime on tenant's runtime dashboard"
    # Start time of the script
    start_time=$(date +%s)
    
    # Duration for timeout in seconds (5 minutes)
    duration=$((3 * 60))
    
    # request to run
    response=$(curl -s -H "authtoken:$AUTH_TOKEN" -H "cookie:$COOKIE" -H "X-csrf-token:$CSRF" "https://$CLOUD_NAME/integration/rest/edge/runtimes/$agentID/instances/")
    echo "RESPONSE: $response"
    status=$(echo "$response" | grep -oP '(?<="status":")[^"]*')
    
    # Loop until the request succeeds or timeout occurs
    while true; do
        if [[ $status == *"Running"* ]]; then
            echo "Edge server status: $status"
            break
        else
            echo "Edge server status: $status, waiting for the status to change, retrying..."
            response=$(curl -s -H "authtoken:$AUTH_TOKEN" -H "cookie:$COOKIE" -H "X-csrf-token:$CSRF" "https://$CLOUD_NAME/integration/rest/edge/runtimes/$agentID/instances/")
            echo "RESPONSE: $response"
            status=$(echo "$response" | grep -oP '(?<="status":")[^"]*')
        fi
    
    # Check if the timeout has been reached
        current_time=$(date +%s)
        if (( current_time - start_time >= duration )); then
            echo "Edge server status: $status, did not change even after waiting for $duration seconds"
            echo "Timeout reached, exiting loop."
            break
        fi
    # Wait for a bit before retrying
        sleep 10
    done
}
configure_edge_runtime_to_tenant(){
     echo "configure the edge server"
     echo "curl -s -H "authtoken:$AUTH_TOKEN""
     response=$(curl -s -X POST -H "Content-Type: application/json" -H "authtoken:$AUTH_TOKEN" -H "cookie:$COOKIE" -H "X-csrf-token:$CSRF" -d "{\"name\":\"$REMOTE_EDGE_SERVER_NAME\",\"description\":\"Remote edge runtime for performance test\"}" "https://$CLOUD_NAME/integration/rest/edge/runtimes?pairInstance=true")

#curl -s -X POST -H "Content-Type: application/json" -H "authtoken:fl92c35f89af67a433f71657" -H "cookie:route=1711024777.792.39.1540|58fb03e5a1678771a75dea209604055b;JSESSIONID=9BB0BAB6615AFA902A3FC61A2C5EBD75;login=;lang=en;UserType=Platform" -H "X-csrf-token:dbc5be18-b7b9-4f20-aa02-ed8ca1fcd075" -d "{\"name\":\"perftest123\",\"description\":\"Remote edge runtime for performance test\"}" "https://originawsint2.int-aw-us1.webmethods-int.io/integration/rest/edge/runtimes?pairInstance=true"
    if [ -z "$response" ]; then
        echo "The response is empty or null"
    else
        echo "RESPONSE: $response"
        pairingCode=$(echo "$response" | grep -oP '(?<="pairingCode":")[^"]*')
        agentID=$(echo "$response" | grep -oP '(?<="agentID":")[^"]*')
        if [ -z "$pairingCode" ]; then
            echo "pairigCode is empty or null"
        else
            echo "The pairing code: $pairingCode"
            echo "creating edge server with pairing code and setting the edge server heap min & max to 4GB"
            docker run -p 5555:5555 -d -e SAG_IS_CLOUD_REGISTER_URL=https://$CLOUD_NAME -e JAVA_MIN_MEM=4096M -e JAVA_MAX_MEM=4096M -e SAG_IS_EDGE_CLOUD_ALIAS=EdgeRuntime_$REMOTE_EDGE_SERVER_NAME -e SAG_IS_CLOUD_REGISTER_TOKEN=$pairingCode --name=$REMOTE_EDGE_SERVER_NAME iregistry.eur.ad.sag/aim/msr-edge-runtime:int
            echo "started docker container"
#           docker run -p 5555:5555 -d -e SAG_IS_CLOUD_REGISTER_URL=https://originawsint2.int-aw-us1.webmethods-int.io -e SAG_IS_EDGE_CLOUD_ALIAS=EdgeRuntime_test2123 -e SAG_IS_CLOUD_REGISTER_TOKEN=9ea88587469842928bec4390eff6aa7f8979cfb0589c4ed2af1e66d21badfc65 --name=test2123 iregistry.eur.ad.sag/aim/msr-edge-runtime:int
            verify_edge_runtime_on_tenant_runtime_dashboard
        fi
    fi
}

fetch_tokens_from_tenant(){
    echo "Fetch auth, cookie, X-csrf-token"
    rm -f token.json
    curl -s -u ${TENANT_USERNAME}:${TENANT_PASSWORD} https://$CLOUD_NAME/enterprise/v1/user/token > token.json
    AUTH_TOKEN=`cat token.json | grep -oP '(?<="authtoken":")[^"]*'`
    COOKIE=`cat token.json | grep -oP '(?<="cookie":")[^"]*'`
    CSRF=`cat token.json | grep -oP '(?<="csrf":")[^"]*'`
}

TENANT_USERNAME=$2
TENANT_PASSWORD=$3
source ./origin.properties # CLOUD_NAME, REMOTE_EDGE_SERVER_NAME will be picked up as environment variables from ./origin.properties file
echo "CLOUD_NAME: $CLOUD_NAME"
echo "REMOTE_EDGE_SERVER_NAME: $REMOTE_EDGE_SERVER_NAME"
echo " Check the docker version "
docker --version
CURRENT_DIRECTORY=$PWD

if [[ $1 == *"pull_edge_runtime_image"* ]]; then
        pull_edge_runtime_image 
fi
if [[ $1 == *"load_edge_runtime_image"* ]]; then
        load_edge_runtime_image 
fi
if [[ $1 == *"delete_existing_edge_runtime_from_tenant"* ]]; then
        fetch_tokens_from_tenant
        delete_existing_edge_runtime_from_tenant
fi
if [[ $1 == *"configure_edge_runtime_to_tenant"* ]]; then
        fetch_tokens_from_tenant
        configure_edge_runtime_to_tenant 
fi