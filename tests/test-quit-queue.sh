#!/bin/bash

rm goodconf *capture* 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=1;
echo -en "channel channel1 $chan1port 5\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 6.3 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture &
sleep 0.3; timeout 6 bash -c "{ $(./decide.sh $1 client) $chan1port Liam; }" > client-capture-A &
sleep 0.4; timeout 6 bash -c "{ $(./decide.sh $1 client) $chan1port Lachlan; }" > /dev/null &
sleep 0.5; timeout 6 bash -c "{ $(./decide.sh $1 client) $chan1port Abraham; }" > /dev/null &
sleep 0.6; timeout 6 bash -c "{ $(./decide.sh $1 client) $chan1port Graham; }" > /dev/null &
sleep 0.7; timeout 6 bash -c "{ $(./decide.sh $1 client) $chan1port Harald; }" > /dev/null &
sleep 0.8; timeout 6 bash -c "{ (sleep 1.4; echo '/quit') | $(./decide.sh $1 client) $chan1port Eleanor; }" > client-capture-B &
sleep 0.9; timeout 1.5 bash -c "{ $(./decide.sh $1 client) $chan1port Ryan; }" > client-capture-C &
sleep 6.4;

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

#rm goodconf *capture* 2> /dev/null;
