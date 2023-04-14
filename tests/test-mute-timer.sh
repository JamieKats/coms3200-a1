#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;
echo -en "channel channel1 1234 10\nchannel channel2 2345 10\nchannel channel2 3456 10" > goodconf;

timeout 1.6 bash -c "{ (sleep 0.3; echo '/mute channel1:Jono 0'; sleep 0.6; echo '/mute channel1:Jono -22') | $(./decide.sh $1 server) goodconf; }"             > server-capture &
timeout 1.5 bash -c "{ (sleep 0.6; echo 'A day may come when I am muted'; sleep 0.6; echo 'But it is not this day') | $(./decide.sh $1 client) 1234 Jono; }"    > client-capture;

sleep 1.7;

echo -e "Jono has joined the channel1 channel.\nInvalid mute time.\nA day may come when I am muted\nInvalid mute time.\nBut it is not this day" > server-capture-compare;
echo -e "Welcome to the channel1 channel, Jono.\nJono has joined the channel.\nA day may come when I am muted\nBut it is not this day"          > client-capture-compare-messages;

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
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
