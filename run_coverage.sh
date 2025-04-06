#!/bin/bash -e
count=0;
perl Build.PL

while true; do
    count=$(($count + 1 ));
    echo "LOOP $count";
    TEST_SHARED=1 TEST_SUBREAPER=1 cover -test -report codecovbash
#    TEST_SHARED=1 TEST_SUBREAPER=1 cover -test -report text
done

