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
        sed -i "s*PATH*$endpointpath*g" JMeterScripts/"$workload".jmx
        sed -i "s*BEARER*$BEARER_TOKEN*g" JMeterScripts/"$workload".jmx
        sed -i "s*APIKEY*$API_KEY*g" JMeterScripts/"$workload".jmx
}

execute_jmeter_script()
{
        echo " execute jmeter script $testcase SCRIPTNAME=$2 THREADS=$3 DURATION=$4 RESULTFILE=$1"
        $JMETER_HOME/bin/jmeter.sh -n -t JMeterScripts/$2.jmx -Jthreads=$3 -Jduration=$4 -l TEMP_DIRECTORY/$2.jtl
        java -jar $JMETER_HOME/lib/cmdrunner-2.2.jar --tool Reporter --generate-csv TEMP_DIRECTORY/$2.csv --input-jtl TEMP_DIRECTORY/$2.jtl --plugin-type SynthesisReport
        cat TEMP_DIRECTORY/$2.csv
        rm -f TEMP_DIRECTORY/$2.jtl
        java -DWORKLOAD_NAME=$2 -DTEMP_DIRECTORY=$5/ -cp bpt_utils.jar perf.bpt.util.CompareBaseline
}

source ./origin.properties # CLOUD_NAME, REMOTE_EDGE_SERVER_NAME will be picked up as environment variables from ./origin.properties file
echo "CLOUD_NAME: $CLOUD_NAME"
echo "REMOTE_EDGE_SERVER_NAME: $REMOTE_EDGE_SERVER_NAME"
File="Tests/Benchmark_testcase_All.csv"
JMETER_HOME=/opt/apache-jmeter-5.6.3/
TEMP_DIRECTORY=$1
BEARER_TOKEN=$2
API_KEY=$3
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
        workload="$testcase"_"$concurrentusers"users
        echo "workload: $workload"
        cp JMeterScripts/$testcase.jmx JMeterScripts/$workload.jmx
        prepare_jmeter_script $workload
        execute_jmeter_script $testcase $workload $concurrentusers $duration $TEMP_DIRECTORY
done
