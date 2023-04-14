#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;
echo -en "channel channel1 1248 10\nchannel channel2 2359 10\nchannel channel3 3470 10" > goodconf;

timeout 1 bash -c "{ (sleep 0.6; echo '/thisisnotacommandsoyoushoulddonothing haha lol') | $(./decide.sh $1 server) goodconf; }" > server-capture &
timeout 0.9 bash -c "{ (sleep 0.3; echo '/thisisalsonotacommandsoyoushoulddonothing haha lol') | $(./decide.sh $1 client) 1248 Chamith; }" > client-capture-A &
timeout 0.9 bash -c "{ $(./decide.sh $1 client) 1248 Peter; }" > client-capture-B;

sleep 1;

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
        echo -e $(diff server-capture-messages server-capture-compare-messages) 2>/dev/null;
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
