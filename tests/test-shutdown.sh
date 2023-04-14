#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;
echo -en "channel channel1 1234 10\nchannel channel2 2345 10\nchannel channel2 3456 10" > goodconf;

timeout 2 bash -c "{ (sleep 0.5; echo '/shutdown') | $(./decide.sh $1 server) goodconf; }" > server-capture &
timeout 2 bash -c "{ (sleep 0.5;) | $(./decide.sh $1 client) 2345 EmptyOne; }" > client-capture-A &
timeout 2 bash -c "{ (sleep 0.5; ) | $(./decide.sh $1 client) 1234 EmptyTwo; }" > client-capture-B &
timeout 2 bash -c "{ (sleep 0.5;) | $(./decide.sh $1 client) 1234 EmptyThree; }" > client-capture-C ;

sleep 2.1;

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

clientsocket1closed=$(ss -ntu | awk '{print $6}' | grep :1234 | wc -l);
clientsocket2closed=$(ss -ntu | awk '{print $6}' | grep :2345 | wc -l);
clientsocket3closed=$(ss -ntu | awk '{print $6}' | grep :3456 | wc -l);
serversocket1closed=$(ss -ntu | awk '{print $5}' | grep :1234 | wc -l);
serversocket2closed=$(ss -ntu | awk '{print $5}' | grep :2345 | wc -l);
serversocket3closed=$(ss -ntu | awk '{print $5}' | grep :3456 | wc -l);

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
    echo -e "\033[0;31mServer logs do not match expected.\033[0m";
    echo -e "\033[0;31m Client sockets are still open that should be shut!\033[0m";
else
    echo -e "\033[0;32mConnections on channel1 closed!\033[0m";
fi  

if [[ serversocketsclosed -gt 0 ]]
then
    echo -e "\033[0;31mServer logs do not match expected.\033[0m";
    echo -e "\033[0;31m Server sockets are still open that should be shut!\033[0m";
else
    echo -e "\033[0;32mConnections on channel2 closed!\033[0m";
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
