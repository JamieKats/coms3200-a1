#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;
echo -en "channel channel1 1238 10\nchannel channel2 2349 10\nchannel channel3 3460 10" > goodconf;

timeout 2 bash -c "{ (sleep 0.5; echo '/empty channel1') | $(./decide.sh $1 server) goodconf; }" > server-capture & #Does this sleep need to be after ??
timeout 2 bash -c "{ (sleep 0.5;) | $(./decide.sh $1 client) 2349 EmptyFour; }" > client-capture-A &
timeout 2 bash -c "{ (sleep 0.5; ) | $(./decide.sh $1 client) 1238 EmptyFive; }" > client-capture-B &
timeout 2 bash -c "{ (sleep 0.5;) | $(./decide.sh $1 client) 1238 EmptySix; }" > client-capture-C ;

sleep 2.1;

echo -e "EmptyFour has joined the channel2 channel.\nEmptyFive has joined the channel1 channel.\nEmptySix has joined the channel1 channel." > server-capture-compare-messages;
echo -e "Welcome to the channel2 channel, EmptyFour.\nEmptyFour has joined the channel." > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, EmptyFive.\nEmptyFive has joined the channel.\nEmptySix has joined the channel." > client-capture-compare-B;
echo -e "Welcome to the channel1 channel, EmptySix.\nEmptySix has joined the channel." > client-capture-compare-C;

awk -F '] ' '{ print $2 }' server-capture > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;
awk -F '] ' '{ print $2 }' client-capture-C > client-capture-C-messages;

servermistakesm=$(diff server-capture-messages server-capture-compare-messages | wc -l);
clientmistakesam=$(diff client-capture-A-messages client-capture-compare-A | wc -l);
clientmistakesbm=$(diff client-capture-B-messages client-capture-compare-B | wc -l);
clientmistakescm=$(diff client-capture-C-messages client-capture-compare-C | wc -l);


clientsocket1closed=$(ss -ntu | awk '{print $6}' | grep :1238 | wc -l);
clientsocket2closed=$(ss -ntu | awk '{print $6}' | grep :2349 | wc -l);

servermistakestot=$[servermistakesm];
clientmistakestot=$[clientmistakesam + clientmistakesbm + clientmistakescm];
clientsocketsclosed=$[clientsocket1closed + clientsocket2closed + clientsocket3closed];


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

if [[ clientsocket1closed -gt 0 ]]
then
    echo -e "\033[0;31m Clients are still connected to channel 1!\033[0m";
else
    echo -e "\033[0;32mAll clients in channel 1 sucessfully kicked!\033[0m";
fi  

if [[ clientsocket2closed -ne 1 ]]
then
    echo -e "\033[0;31mA client should still be connected to channel 2!\033[0m";
else
    echo -e "\033[0;32mThe client in channel 2 is still connected!\033[0m";
fi  

if [[ clientmistakestot -gt 0 ]]
then
    echo -e "\033[0;31mClients' message logs do not match expected.\033[0m";
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
