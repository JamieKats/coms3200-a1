#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 8 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture                                 &
sleep 0.3; timeout 5.5 bash -c "{ (sleep 1.1; echo 'Hi Nobody') | $(./decide.sh $1 client) $chan2port Terry; }" > client-capture-A &
sleep 0.4; timeout 5.5 bash -c "{ (sleep 1.3; echo 'Hi Eric') | $(./decide.sh $1 client) $chan1port Henry; }" > client-capture-B   &
sleep 0.5; timeout 5.5 bash -c "{ (sleep 1.5; echo 'Hi Henry') | $(./decide.sh $1 client) $chan1port Eric; }" > client-capture-C   &
sleep 8.1;

echo -e "Terry has joined the channel2 channel.\nHenry has joined the channel1 channel.\nEric has joined the channel1 channel.\nHi Nobody\nHi Eric\nHi Henry" > server-capture-compare;
echo -e "Welcome to the channel2 channel, Terry.\nTerry has joined the channel.\nHi Nobody" > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, Henry.\nHenry has joined the channel.\nEric has joined the channel.\nHi Eric\nHi Henry" > client-capture-compare-B;
echo -e "Welcome to the channel1 channel, Eric.\nEric has joined the channel.\nHi Eric\nHi Henry" > client-capture-compare-C;

awk -F '] ' '{ print $2 }' server-capture > server-capture-1;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-1;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-1;
awk -F '] ' '{ print $2 }' client-capture-C > client-capture-C-1;

servermistakes=$(diff server-capture-1 server-capture-compare | wc -l);
clientmistakes1=$(diff client-capture-A-1 client-capture-compare-A | wc -l);
clientmistakes2=$(diff client-capture-B-1 client-capture-compare-B | wc -l);
clientmistakes2=$(diff client-capture-C-1 client-capture-compare-C | wc -l);
clientmistakestot=$[clientmistakes1 + clientmistakes2 + clientmistakes3];

if [[ servermistakes -gt 0 ]]
then
    echo -e "\033[0;31mServer logs do not match expected.\033[0m";
    if [[ DEBUG -eq 1 ]]
    then
        echo -e $(diff server-capture-1 server-capture-compare) 2>/dev/null;
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
        echo -e "$(diff client-capture-A-1 client-capture-compare-A)" 2>/dev/null;
        echo -e "--------";
        echo -e "Client B"
        echo -e "--------";
        echo -e "$(diff client-capture-B-1 client-capture-compare-B)"  2>/dev/null;
        echo -e "--------";
        echo -e "Client C";
        echo -e "--------";
        echo -e "$(diff client-capture-C-1 client-capture-compare-C)"  2>/dev/null;
        echo -e "--------";
    fi
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
