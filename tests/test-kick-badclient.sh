#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;

echo -en "channel channel1 1240 10\nchannel channel2 2351 10\nchannel channel3 3462 10" > goodconf;

timeout 1 bash -c "{ (sleep 0.5; echo '/kick channel1:Glover') | $(./decide.sh $1 server) goodconf; }" > server-capture &
timeout 1 bash -c "{ (sleep 0.5;) | $(./decide.sh $1 client) 2345 Joseph; }" > client-capture-A &
timeout 1 bash -c "{ (sleep 0.5; ) | $(./decide.sh $1 client) 1234 Donald; }" > client-capture-B &
timeout 1 bash -c "{ (sleep 0.5;) | $(./decide.sh $1 client) 1234 Joe; }" > client-capture-C ;

sleep 1.1;

echo -e "Joseph has joined the channel2 channel.\nDonald has joined the channel1 channel.\nJoe has joined the channel1 channel.\nGlover is not in channel1." > server-capture-compare-messages;
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
        echo -e $(diff server-capture-messages server-capture-compare-messages) 2>/dev/null;
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
