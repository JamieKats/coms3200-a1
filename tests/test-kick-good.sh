#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

socketchan1=$(mktemp)
socketchan2=$(mktemp)

echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 4 bash -c "{ (sleep 1.7; echo '/kick channel1:Joe') | $(./decide.sh $1 server) goodconf; }" > server-capture &
sleep 0.3; timeout 2.5 bash -c "{ $(./decide.sh $1 client) $chan2port Joseph; }" > client-capture-A &
sleep 0.4; timeout 2.5 bash -c "{ $(./decide.sh $1 client) $chan1port Glover; }" > client-capture-B &
sleep 0.5; timeout 2.5 bash -c "{ $(./decide.sh $1 client) $chan1port Joe; }" > client-capture-C &
sleep 1; bash -c "{ (ss -ntu | awk '{print \$6}' | grep :$chan1port | wc -l) }" > "$socketchan1" &
bash -c "{ (ss -ntu | awk '{print \$6}' | grep :$chan2port | wc -l) }" > "$socketchan2" &
sleep 4.1 & wait;

export clientsocket1closed=$(<$socketchan1)
export clientsocket2closed=$(<$socketchan2)

echo -e "Joseph has joined the channel2 channel.\nGlover has joined the channel1 channel.\nJoe has joined the channel1 channel.\nKicked Joe." > server-capture-compare-messages;
echo -e "[Server message\n[Server message\n[Server message\n" > server-capture-compare-names;
echo -e "Welcome to the channel2 channel, Joseph.\nJoseph has joined the channel." > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, Glover.\nGlover has joined the channel.\nJoe has joined the channel.\nJoe has left the channel." > client-capture-compare-B;
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

if [[ clientsocket1closed -ne 1 ]]
then
    echo -e "\033[0;31mExpecting 1 client left in channel 1, either 0 or 2 clients were found connected to channel 1!\033[0m";
else
    echo -e "\033[0;32mCorrect number of clients left in channel1.\033[0m";
fi  

if [[ clientsocket2closed -ne 1 ]]
then
    echo -e "\033[0;31mExpecting 1 client left in channel 2, and there are none!\033[0m";
else
    echo -e "\033[0;32mCorrect number of clients left in channel2.\033[0m";
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
