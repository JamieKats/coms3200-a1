#!/bin/bash
CMD="$(./decide.sh $1 server) badcap";

rm badcap 2> /dev/null

echo -en "channel channel1 1234 10\nchannel channel2 2345 1a\nchannel channel2 3456 10" > badcap

timeout 0.2 $CMD;
if [[ $? -ne 1 ]]
then
    echo -en "\033[0;31mServer did not reject config correctly.";
else
    echo -en "\033[0;32mServer rejected config correctly.";
fi
echo -e '\033[0m'

rm badcap 2> /dev/null
