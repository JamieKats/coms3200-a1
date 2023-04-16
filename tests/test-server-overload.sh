#!/bin/bash

CMD="$(./decide.sh $1 server good extra rubbish to reject)";
rm good 2> /dev/null

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > good

timeout 0.3 $CMD;
if [[ $? -ne 1 ]]
then
    echo -en "\033[0;31mServer did not exit correctly.";
else
    echo -en "\033[0;32mServer exited correctly.";
fi
echo -e '\033[0m'

rm good 2> /dev/null
