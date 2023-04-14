#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;
echo -en "channel channel1 1250 10\nchannel channel2 2361 10\nchannel channel3 3472 10" > goodconf;

timeout 1.2 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture &
timeout 1 bash -c "{ (sleep 0.3; echo 'Hi'; sleep 0.2; echo '/quit') | $(./decide.sh $1 client) 1250 Gordon; }" > client-capture-A &
timeout 1 bash -c "{ (sleep 0.7; echo 'You will not receive this') | $(./decide.sh $1 client) 1250 Amos; }" > client-capture-B;

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
