#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;
echo -en "channel channel1 1234 10\nchannel channel2 2345 10\nchannel channel2 3456 10" > goodconf;

timeout 1 bash -c "{ (sleep 0.3; echo '/mute channel1:nonexist 22') | $(./decide.sh $1 server) goodconf; }" > server-capture &
timeout 0.9 bash -c "{ (sleep 0.6; echo 'Not muted yay') | $(./decide.sh $1 client) 1234 Dave; }"           > client-capture;

sleep 1.1;

echo -e "Dave has joined the channel1 channel.\nnonexist is not here.\nNot muted yay"           > server-capture-compare;
echo -e "Welcome to the channel1 channel, Dave.\nDave has joined the channel.\nNot muted yay"   > client-capture-compare-messages;

awk -F '] ' '{ print $2 }' server-capture   > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture   > client-capture-messages;

servermistakes=$(diff server-capture-messages server-capture-compare | wc -l);
clientmistakes=$(diff client-capture-messages client-capture-compare-messages | wc -l);

if [[ servermistakes -gt 0 ]]
then
    echo -e "\033[0;31mServer logs do not match expected.\033[0m";
    if [[ DEBUG -eq 1 ]]
    then
        echo -e $(diff server-capture-messages server-capture-compare-messages) 2>/dev/null;
    fi
else
    echo -e "\033[0;32mServer logs match expected.\033[0m";
fi

if [[ clientmistakes -gt 0 ]]
then
    echo -e "\033[0;31mClients' message logs do not match expected.\033[0m";
    cat client-capture-messages;
    echo
    cat client-capture-compare-messages;
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
