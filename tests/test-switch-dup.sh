#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;
echo -en "channel channel1 1259 10\nchannel channel2 2370 10\nchannel channel3 3481 10" > goodconf;

timeout 1.1 bash -c "{ $(./decide.sh $1 server) goodconf; }"    > server-capture    &
timeout 1 bash -c "{ (sleep 0.3; echo 'Hi channel 1'; sleep 0.3; echo '/switch channel2'; sleep 0.3; echo 'Still here') | $(./decide.sh $1 client) 1259 Suhas; }" > client-capture-A &
timeout 1 bash -c "{ $(./decide.sh $1 client) 1259 Pragun; }"    > client-capture-B  &
timeout 1 bash -c "{ sleep 0.1; $(./decide.sh $1 client) 2370 Suhas; }"    > client-capture-C;

sleep 1.2;

echo -e "Suhas has joined the channel1 channel.\nPragun has joined the channel1 channel.\nSuhas has joined the channel2 channel.\nHi channel 1\nStill here" > server-capture-compare;
echo -e "Welcome to the channel1 channel, Suhas.\nSuhas has joined the channel.\nPragun has joined the channel.\nHi channel 1\nCannot switch to the channel2 channel.\nStill here" > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, Pragun.\nPragun has joined the channel.\nHi channel 1\nStill here" > client-capture-compare-B;
echo -e "Welcome to the channel2 channel, Suhas.\nSuhas has joined the channel." > client-capture-compare-C;

awk -F '] ' '{ print $2 }' server-capture   > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;
awk -F '] ' '{ print $2 }' client-capture-C > client-capture-C-messages;

servermistakes=$(diff server-capture-messages server-capture-compare        | wc -l);
clientmistakesa=$(diff client-capture-A-messages client-capture-compare-A   | wc -l);
clientmistakesb=$(diff client-capture-B-messages client-capture-compare-B   | wc -l);
clientmistakesc=$(diff client-capture-C-messages client-capture-compare-C   | wc -l);

clientmistakestot=$[clientmistakesa + clientmistakesb + clientmistakesc];

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
        echo -e "Client D";
        echo -e "--------";
        echo -e "$(diff client-capture-D-messages client-capture-compare-D)"  2>/dev/null;
        echo -e "--------";
    fi
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
