#!/bin/sh
store_test_results()
{
        echo " store test results jmeter script "
        cat temp.txt
        run_id=$(cat temp.txt)
        echo run id: $run_id
        java -DTEST_MASTER_KEY=ORIGIN_AWS_BPT -DRUN_ID=$run_id -DRETRY_ID=0 -DWORKLOAD_NAME=$testcase -DBASELINE_VERSION=10.15 -DPRODUCT_BUILD_NUMBER=ORIGIN_10.16.0.0 -DINSTALLED_INT_FIXES=None -DINSTALLED_GA_FIXES=None -DBUILD_NUMBER_OTHERS=None -DINSTALLED_FIXES_OTHERS=None -DTEST_DURATION=$duration -DCONCURRENT_USERS=$concurrentusers -DTEMP_DIRECTORY=TEMP_DIRECTORY/ -DSERVERS_TO_BE_MONITORED=ORIGIN-NA -cp bpt_utils.jar perf.bpt.ProcessTestResults
}

File="TestScripts/Benchmark_testcase_All.csv"
JMETER_HOME=/home/centos/apache-jmeter-5.2
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
        store_test_results $workload $concurrentusers $duration
done
