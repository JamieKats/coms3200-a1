#!/bin/bash
CMD="$(./decide.sh $1 server) badname";

rm badname 2> /dev/null

echo -en "channel channel1 1234 10\nchannel 1hannel2 2345 10\nchannel channel3 1234 10" > badname

timeout 0.1 $CMD;
if [[ $? -ne 1 ]]
then
    echo -en "\033[0;31mServer did not reject config correctly.";
else
    echo -en "\033[0;32mServer rejected config correctly.";
fi
echo -e '\033[0m'

rm badname 2> /dev/null
