#!/bin/bash

CMD="$(./decide.sh $1 server)";
timeout 0.1 $CMD;
if [[ $? -ne 1 ]]
then
    echo -en "\033[0;31mServer did not exit correctly.";
else
    echo -en "\033[0;32mServer exited correctly.";
fi
echo -e '\033[0m'
