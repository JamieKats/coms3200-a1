#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;
echo -en "channel channel1 1251 5\nchannel channel2 2362 10\nchannel channel3 3473 10" > goodconf;

timeout 1.2 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture &
timeout 1 bash -c "{ $(./decide.sh $1 client) 1234 Liam; }" > client-capture-A &
timeout 1 bash -c "{ $(./decide.sh $1 client) 1234 Lachlan; }" > /dev/null &
timeout 1 bash -c "{ $(./decide.sh $1 client) 1234 Abraham; }" > /dev/null &
timeout 1 bash -c "{ $(./decide.sh $1 client) 1234 Graham; }" > /dev/null &
timeout 1 bash -c "{ $(./decide.sh $1 client) 1234 Harald; }" > /dev/null &
timeout 1 bash -c "{ (sleep 0.5; echo '/quit') | $(./decide.sh $1 client) 1234 Eleanor; }" > client-capture-B &
timeout 1 bash -c "{ $(./decide.sh $1 client) 1234 Ryan; }" > client-capture-C;

sleep 1.3;

echo -e "Liam has joined the channel1 channel.\nLachlan has joined the channel1 channel.\nAbraham has joined the channel1 channel.\nGraham has joined the channel1 channel.\nHarald has joined the channel1 channel.\nEleanor has left the channel." > server-capture-compare;
echo -e "Welcome to the channel1 channel, Liam.\nLiam has joined the channel.\nLachlan has joined the channel.\nAbraham has joined the channel.\nGraham has joined the channel.\nHarald has joined the channel." > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, Eleanor.\nYou are in the waiting queue and there are 0 user(s) ahead of you." > client-capture-compare-B;
echo -e "Welcome to the channel1 channel, Ryan.\nYou are in the waiting queue and there are 1 user(s) ahead of you.\nYou are in the waiting queue and there are 0 user(s) ahead of you." > client-capture-compare-C;

awk -F '] ' '{ print $2 }' server-capture > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;
awk -F '] ' '{ print $2 }' client-capture-C > client-capture-C-messages;

servermistakes=$(diff server-capture-messages server-capture-compare | wc -l);
clientmistakes1=$(diff client-capture-A-messages client-capture-compare-A | wc -l);
clientmistakes2=$(diff client-capture-B-messages client-capture-compare-B | wc -l);
clientmistakes3=$(diff client-capture-C-messages client-capture-compare-C | wc -l);
clientmistakestot=$[clientmistakes1 + clientmistakes2 + clientmistakes3];

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

if [[ clientmistakestot -gt 0 ]]
then
    echo -e "\033[0;31mClients' message logs do not match expected.\033[0m";
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
