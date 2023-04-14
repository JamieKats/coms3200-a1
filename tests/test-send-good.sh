#!/bin/bash

rm goodconf *capture* 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=1;
rm ./testtmp/AsFile.txt 2> /dev/null;
rmdir ./testtmp 2> /dev/null;

mkdir ./testtmp;
echo -e "testing send!" >> ./testtmp/AsFile.txt;

echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 1.1 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture &
timeout 1 bash -c "{ (sleep 0.5; ) | $(./decide.sh $1 client) $chan1port ReceiverOne; }" > client-capture-A &
timeout 1 bash -c "{ (sleep 0.75; echo -e '/send ReceiverOne ./testtmp/AsFile.txt' ) | $(./decide.sh $1 client) $chan1port SenderOne; }" > client-capture-B &
sleep 1.2;

echo -e "ReceiverOne has joined the channel1 channel.\nSenderOne has joined the channel1 channel.\nSenderOne sent ./testtmp/AsFile.txt to ReceiverOne." > server-capture-compare;
echo -e "Welcome to the channel1 channel, ReceiverOne.\nReceiverOne has joined the channel.\nSenderOne has joined the channel." > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, SenderOne.\nSenderOne has joined the channel.\nYou sent ./testtmp/AsFile.txt to ReceiverOne." > client-capture-compare-B;

awk -F '] ' '{ print $2 }' server-capture > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;

servermistakesm=$(diff server-capture-messages server-capture-compare | wc -l);
clientmistakesam=$(diff client-capture-A-messages client-capture-compare-A | wc -l);
clientmistakesbm=$(diff client-capture-B-messages client-capture-compare-B | wc -l);
filemistakes=$(diff ./testtmp/AsFile.txt ./AsFile.txt | wc -l);

servermistakestot=$[servermistakesm];
clientmistakestot=$[clientmistakesam + clientmistakesbm];
filemistakes=$[filemistakes]


if [[ servermistakestot -gt 0 ]]
then
    echo -e "\033[0;31mServer logs do not match expected.\033[0m";\
else
    echo -e "\033[0;32mServer logs match expected.\033[0m";
fi


if [[ filemistakes -ne "0" ]]
then
    echo -e "\033[0;31mThe file did not transfer as expected, files are different.\033[0m";
    echo -e "Contents of original file\n------";
    cat ./testtmp/AsFile.txt;
    echo -e "Contents of Transferred file\n------";
    cat ./AsFile.txt;
    echo -e "\nDiff output";
    echo $(diff ./testtmp/AsFile.txt ./AsFile.txt);
else
    echo -e "\033[0;32mFile transfer completed sucessfully.\033[0m";
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

rm testtmp goodconf *capture*   2> /dev/null;
