#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

socketchan1=$(mktemp)
socketchan2=$(mktemp)

echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 3 bash -c "{ (sleep 1.6; echo '/empty channel1') | $(./decide.sh $1 server) goodconf; }" > server-capture & #Does this sleep need to be after ??
sleep 0.3; timeout 2.2 bash -c "{ $(./decide.sh $1 client) $chan2port EmptyFour; }" > client-capture-A &
sleep 0.4; timeout 2.2 bash -c "{ $(./decide.sh $1 client) $chan1port EmptyFive; }" > client-capture-B &
sleep 0.5; timeout 2.2 bash -c "{ $(./decide.sh $1 client) $chan1port EmptySix; }" > client-capture-C &
sleep 0.7; bash -c "{ (ss -ntu | awk '{print \$6}' | grep :$chan1port | wc -l) }" > "$socketchan1" &
bash -c "{ (ss -ntu | awk '{print \$6}' | grep :$chan2port | wc -l) }" > "$socketchan2" &
sleep 3.1 & wait;

export clientsocket1closed=$(<$socketchan1)
export clientsocket2closed=$(<$socketchan2)
echo -e "EmptyFour has joined the channel2 channel.\nEmptyFive has joined the channel1 channel.\nEmptySix has joined the channel1 channel.\nchannel1 has been emptied." > server-capture-compare-messages;
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
