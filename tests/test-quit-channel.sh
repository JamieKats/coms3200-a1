#!/bin/bash

rm goodconf *capture* 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=0;
echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 1.2 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture &
timeout 1 bash -c "{ (sleep 0.3; echo 'Hi'; sleep 0.2; echo '/quit') | $(./decide.sh $1 client) $chan1port Gordon; }" > client-capture-A &
timeout 1 bash -c "{ (sleep 0.7; echo 'You will not receive this') | $(./decide.sh $1 client) $chan1port Amos; }" > client-capture-B &
sleep 1.5;

echo -e "Gordon has joined the channel1 channel.\nAmos has joined the channel1 channel.\nHi\nGordon has left the channel.\nYou will not receive this" > server-capture-compare;
echo -e "Welcome to the channel1 channel, Gordon.\nGordon has joined the channel.\nAmos has joined the channel.\nHi" > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, Amos.\nAmos has joined the channel.\nHi\nGordon has left the channel.\nYou will not receive this" > client-capture-compare-B;

awk -F '] ' '{ print $2 }' server-capture > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;

servermistakes=$(diff server-capture-messages server-capture-compare | wc -l);
clientmistakes1=$(diff client-capture-A-messages client-capture-compare-A | wc -l);
clientmistakes2=$(diff client-capture-B-messages client-capture-compare-B | wc -l);
clientmistakestot=$[clientmistakes1 + clientmistakes2];

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

if [[ clientmistakestot -gt 0 ]]
then
    echo -e "\033[0;31mClients' message logs do not match expected.\033[0m";
    if [[ DEBUG -eq 1 ]]
    then
        echo -e "Client A";
        echo -e "--------";
        echo -e "$(diff client-capture-A-messages client-capture-compare-A)" 2>/dev/null;
        echo -e "--------";
        echo -e "Client B"
        echo -e "--------";
        echo -e "$(diff client-capture-B-messages client-capture-compare-B)"  2>/dev/null;
    fi
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
