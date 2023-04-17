#!/bin/bash

rm goodconf *capture* 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=1;
echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 2.5 bash -c "{ (sleep 1; echo '/thisisnotacommandsoyoushoulddonothing haha lol') | $(./decide.sh $1 server) goodconf; }" > server-capture &
sleep 0.2; timeout 1.3 bash -c "{ (sleep 0.75; echo '/thisisalsonotacommandsoyoushoulddonothing haha lol') | $(./decide.sh $1 client) $chan1port Chamith; }" > client-capture-A &
sleep 0.3; timeout 1.3 bash -c "{ $(./decide.sh $1 client) $chan1port Peter; }" > client-capture-B &
sleep 2.6;

echo -e "Chamith has joined the channel1 channel.\nPeter has joined the channel1 channel.\n/thisisalsonotacommandsoyoushoulddonothing haha lol" > server-capture-compare;
echo -e "Welcome to the channel1 channel, Chamith.\nChamith has joined the channel.\nPeter has joined the channel.\n/thisisalsonotacommandsoyoushoulddonothing haha lol" > client-capture-compare-messages;
echo -e "[Server message\n[Server message\n[Chamith" > client-capture-compare-names;

awk -F '] ' '{ print $2 }' server-capture   > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-messages;
awk -F ' \\\(' '{ print $1 }' client-capture-B > client-capture-names 2> /dev/null;

servermistakes=$(diff server-capture-messages server-capture-compare | wc -l);
clientmistakesm=$(diff client-capture-messages client-capture-compare-messages | wc -l);
clientmistakesn=$(diff client-capture-names client-capture-compare-names| wc -l);
clientmistakest=$[clientmistakesn + clientmistakesm];

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

if [[ clientmistakest -gt 0 ]]
then
    echo -e "\033[0;31mClients' message logs do not match expected.\033[0m";
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
