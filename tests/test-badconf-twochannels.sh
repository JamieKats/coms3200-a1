#!/bin/bash
CMD="$(./decide.sh $1 server) missing";

rm missing 2> /dev/null

echo -en "channel channel1 1234 10\nchannel channel2 2345 10" > missing

timeout 0.1 $CMD;
if [[ $? -ne 1 ]]
then
    echo -en "\033[0;31mServer did not reject config correctly.";
else
    echo -en "\033[0;32mServer rejected config correctly.";
fi
echo -e '\033[0m'

rm missing 2> /dev/null
