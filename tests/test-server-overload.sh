#!/bin/bash

CMD="$(./decide.sh $1 server good extra rubbish to reject)";
rm good 2> /dev/null

echo -en "channel channel1 1256 10\nchannel channel2 2367 10\nchannel channel3 3478 10" > good

timeout 0.1 $CMD;
if [[ $? -ne 1 ]]
then
    echo -en "\033[0;31mServer did not exit correctly.";
else
    echo -en "\033[0;32mServer exited correctly.";
fi
echo -e '\033[0m'

rm good 2> /dev/null
