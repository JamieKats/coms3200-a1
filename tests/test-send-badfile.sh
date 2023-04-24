#!/bin/bash

rm goodconf *capture* 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=0;
echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 3 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture &
sleep 0.2; timeout 1.7 bash -c "{ $(./decide.sh $1 client) $chan1port ReceiverTwo; }" > client-capture-A &
sleep 0.3; timeout 1.7 bash -c "{ (sleep 0.75; echo -e '/send ReceiverTwo ./testtmp/AsFile.txt' ) | $(./decide.sh $1 client) $chan1port SenderTwo; }" > client-capture-B &
sleep 3.1;

echo -e "ReceiverTwo has joined the channel1 channel.\nSenderTwo has joined the channel1 channel." > server-capture-compare-messages;
echo -e "Welcome to the channel1 channel, ReceiverTwo.\nReceiverTwo has joined the channel.\nSenderTwo has joined the channel." > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, SenderTwo.\nSenderTwo has joined the channel.\n./testtmp/AsFile.txt does not exist." > client-capture-compare-B;

awk -F ' \\\(' '{ print $1 }' server-capture > server-capture-names 2> /dev/null;
awk -F '] ' '{ print $2 }' server-capture > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;

servermistakesm=$(diff server-capture-messages server-capture-compare-messages | wc -l);
clientmistakesam=$(diff client-capture-A-messages client-capture-compare-A | wc -l);
clientmistakesbm=$(diff client-capture-B-messages client-capture-compare-B | wc -l);

servermistakestot=$[servermistakesm];
clientmistakestot=$[clientmistakesan + clientmistakesam + clientmistakesbn + clientmistakesbm + clientmistakescn + clientmistakescm];
filemistakes=$[filemistakes]


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
    fi
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm ./AsFile.txt         2> /dev/null;
rm ./testtmp/AsFile.txt         2> /dev/null;
rmdir ./testtmp                 2> /dev/null;

rm testtmp goodconf *capture* 2> /dev/null;
