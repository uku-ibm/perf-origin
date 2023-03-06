#!/bin/sh
prepare_jmeter_script()
{
        echo " prepare jmeter script "
        file="./origin.properties"
        while IFS='=' read -r key value; do
                echo "key: $key, value: $value"
                sed -i "s*$key*$value*g" JMeterScripts/"$workload".jmx
        done < "$file"
}

execute_jmeter_script()
{
        echo " execute jmeter script "
        $JMETER_HOME/bin/jmeter.sh -n -t JMeterScripts/$1.jmx -Jthreads=$2 -Jduration=$3 -l TEMP_DIRECTORY/$1.jtl
        java -jar $JMETER_HOME/lib/CMDRunner.jar --tool Reporter --generate-csv TEMP_DIRECTORY/$1.csv --input-jtl TEMP_DIRECTORY/$1.jtl --plugin-type SynthesisReport
}

File="TestScripts/Benchmark_testcase_All.csv"
JMETER_HOME=/home/centos/apache-jmeter-5.2
Lines=$(cat $File)
for Line in $Lines
do
        echo "PRINT:: $Line"
        variable=$Line
        if [[ $variable == *"testcase"* ]]; then
                continue
        fi
        IFS=', ' read -r -a array <<< "$variable"
        echo "${array[0]}"
        echo "${array[1]}"
        echo "${array[2]}"
        testcase=${array[0]}
        concurrentusers=${array[1]}
        duration=${array[2]}
        workload="$testcase"_"$concurrentusers"
        echo "workload: $workload"
        cp JMeterScripts/$testcase.jmx JMeterScripts/$workload.jmx
        prepare_jmeter_script $workload
        execute_jmeter_script $workload $concurrentusers $duration $path
done