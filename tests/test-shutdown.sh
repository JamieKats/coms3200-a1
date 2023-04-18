#!/bin/bash

rm goodconf *capture* 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=0;

clientsocketchan1=$(mktemp)
clientsocketchan2=$(mktemp)
clientsocketchan3=$(mktemp)
serversocketchan1=$(mktemp)
serversocketchan2=$(mktemp)
serversocketchan3=$(mktemp)

echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 3.2 bash -c "{ (sleep 1.6; echo '/shutdown') | $(./decide.sh $1 server) goodconf; }" > server-capture &
sleep 0.2; timeout 2 bash -c "{ $(./decide.sh $1 client) $chan2port EmptyOne; }" > client-capture-A &
sleep 0.3; timeout 2 bash -c "{ $(./decide.sh $1 client) $chan1port EmptyTwo; }" > client-capture-B &
sleep 0.4; timeout 2 bash -c "{ $(./decide.sh $1 client) $chan1port EmptyThree; }" > client-capture-C &
sleep 1.1; bash -c "{ (ss -ntu | awk '{print \$6}' | grep :$chan1port | wc -l) }" > "$clientsocketchan1" &
bash -c "{ (ss -ntu | awk '{print \$6}' | grep :$chan2port | wc -l) }" > "$clientsocketchan2" &
bash -c "{ (ss -ntu | awk '{print \$6}' | grep :$chan3port | wc -l) }" > "$clientsocketchan3" &
bash -c "{ (ss -ntu | awk '{print \$5}' | grep :$chan1port | wc -l) }" > "$serversocketchan1" &
bash -c "{ (ss -ntu | awk '{print \$5}' | grep :$chan2port | wc -l) }" > "$serversocketchan2" &
bash -c "{ (ss -ntu | awk '{print \$5}' | grep :$chan3port | wc -l) }" > "$serversocketchan3" &
sleep 3.3 & wait;

export clientsocket1closed=$(<$clientsocketchan1)
export clientsocket2closed=$(<$clientsocketchan2)
export clientsocket3closed=$(<$clientsocketchan3)
export serversocket1closed=$(<$serversocketchan1)
export serversocket2closed=$(<$serversocketchan2)
export serversocket3closed=$(<$serversocketchan3)

echo -e "EmptyOne has joined the channel2 channel.\nEmptyTwo has joined the channel1 channel.\nEmptyThree has joined the channel1 channel." > server-capture-compare-messages;
echo -e "[Server message\n[Server message\n[Server message\n" > server-capture-compare-names;
echo -e "Welcome to the channel2 channel, EmptyOne.\nEmptyOne has joined the channel." > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, EmptyTwo.\nEmptyTwo has joined the channel.\nEmptyThree has joined the channel." > client-capture-compare-B;
echo -e "Welcome to the channel1 channel, EmptyThree.\nEmptyThree has joined the channel." > client-capture-compare-C;

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
clientsocketsclosed=$[clientsocket1closed + clientsocket2closed + clientsocket3closed]
serversocketsclosed=$[serversocket1closed + serversocket2closed + serversocket3closed]


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

if [[ clientsocketsclosed -gt 0 ]]
then
    echo -e "\033[0;31m Client sockets are still open that should be shut!\033[0m";
else
    echo -e "\033[0;32mAll Client sockets closed\033[0m";
fi  

if [[ serversocketsclosed -gt 0 ]]
then
    echo -e "\033[0;31m Server sockets are still open that should be shut!\033[0m";
else
    echo -e "\033[0;32mAll Server Sockets Closed!\033[0m";
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
