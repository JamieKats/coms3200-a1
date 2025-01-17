#!/bin/bash

CMD="$(./decide.sh $1 client username)";
timeout 0.3 $CMD;
if [[ $? -ne 1 ]]
then
    echo -en "\033[0;31mClient did not exit correctly.";
else
    echo -en "\033[0;32mClient exited correctly.";
fi
echo -e '\033[0m'
