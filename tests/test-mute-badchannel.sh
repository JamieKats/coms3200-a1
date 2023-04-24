#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 2.5 bash -c "{ ( sleep 0.7; echo '/mute nonexistentchannel:Paul 22') | $(./decide.sh $1 server) goodconf; }"   > server-capture &
sleep 0.3; timeout 1.5 bash -c "{ ( sleep 0.9; echo 'Not muted yay') | $(./decide.sh $1 client) $chan1port Paul; }"                   > client-capture &
sleep 2.6;

echo -e "Paul has joined the channel1 channel.\nPaul is not here.\nNot muted yay"               > server-capture-compare;
echo -e "Welcome to the channel1 channel, Paul.\nPaul has joined the channel.\nNot muted yay"   > client-capture-compare-messages;

awk -F '] ' '{ print $2 }' server-capture   > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture   > client-capture-messages;

servermistakes=$(diff server-capture-messages server-capture-compare | wc -l);
clientmistakes=$(diff client-capture-messages client-capture-compare-messages | wc -l);

if [[ servermistakes -gt 0 ]]
then
    echo -e "\033[0;31mServer logs do not match expected.\033[0m";
    if [[ DEBUG -eq 1 ]]
    then
        echo -e $(diff server-capture-messages server-capture-compare) 2>/dev/null;
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
