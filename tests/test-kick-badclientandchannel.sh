#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 4 bash -c "{ (sleep 1.3; echo '/kick channel42:Glover') | $(./decide.sh $1 server) goodconf; }" > server-capture &
sleep 0.2; timeout 1.6 bash -c "{ $(./decide.sh $1 client) $chan2port Joseph; }" > client-capture-A &
sleep 0.3; timeout 1.6 bash -c "{ $(./decide.sh $1 client) $chan1port Donald; }" > client-capture-B &
sleep 0.4; timeout 1.6 bash -c "{ $(./decide.sh $1 client) $chan1port Joe; }" > client-capture-C &
sleep 4.1;

echo -e "Joseph has joined the channel2 channel.\nDonald has joined the channel1 channel.\nJoe has joined the channel1 channel.\nGlover is not in channel42.\nchannel42 does not exist." > server-capture-compare-messages;
echo -e "[Server message\n[Server message\n[Server message\n" > server-capture-compare-names;
echo -e "Welcome to the channel2 channel, Joseph.\nJoseph has joined the channel." > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, Donald.\nDonald has joined the channel.\nJoe has joined the channel." > client-capture-compare-B;
echo -e "Welcome to the channel1 channel, Joe.\nJoe has joined the channel." > client-capture-compare-C;

awk -F ' \\\(' '{ print $1 }' server-capture > server-capture-names 2> /dev/null;
awk -F '] ' '{ print $2 }' server-capture > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;
awk -F '] ' '{ print $2 }' client-capture-C > client-capture-C-messages;

servermistakesm=$(diff server-capture-messages server-capture-compare-messages | wc -l);
clientmistakesam=$(diff client-capture-A-messages client-capture-compare-A | wc -l);
clientmistakesbm=$(diff client-capture-B-messages client-capture-compare-B | wc -l);
clientmistakescm=$(diff client-capture-C-messages client-capture-compare-C | wc -l);

servermistakestot=$[servermistakesm];
clientmistakestot=$[clientmistakesam + clientmistakesbm + clientmistakescm];

if [[ servermistakestot -gt 0 ]]
then
    echo -e "\033[0;31mServer logs do not match expected.\033[0m";
    if [[ DEBUG -eq 1 ]]
    then
        echo -e $(diff server-capture-messages server-capture-compare-messages);
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
        echo -e "--------";
        echo -e "Client C";
        echo -e "--------";
        echo -e "$(diff client-capture-C-messages client-capture-compare-C)"  2>/dev/null;
        echo -e "--------";
    fi
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
