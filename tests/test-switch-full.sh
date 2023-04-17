#!/bin/bash

rm goodconf *capture* 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=1;
echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 5\nchannel channel3 $chan3port 10" > goodconf;

timeout 7 bash -c "{ $(./decide.sh $1 server) goodconf; }"                > server-capture    &
sleep 0.2; timeout 6 bash -c "{ (sleep 5; echo 'Hi channel 1'; sleep 0.3; echo '/switch channel2'; sleep 0.3; echo 'Hi channel 2') | $(./decide.sh $1 client) $chan1port Cody; }" > client-capture-A &
sleep 0.3; timeout 6 bash -c "{ $(./decide.sh $1 client) $chan2port full1; }"              > client-capture-B  &
sleep 0.4; timeout 6 bash -c "{ $(./decide.sh $1 client) $chan2port full2; }"              > /dev/null         &
sleep 0.5; timeout 6 bash -c "{ $(./decide.sh $1 client) $chan2port full3; }"              > /dev/null         &
sleep 0.6; timeout 6 bash -c "{ $(./decide.sh $1 client) $chan2port full4; }"              > /dev/null         &
sleep 0.7; timeout 5.8 bash -c "{ $(./decide.sh $1 client) $chan2port full5; }"              > /dev/null         &
sleep 0.8; timeout 5.8 bash -c "{ $(./decide.sh $1 client) $chan2port full6; }"   > /dev/null &
sleep 7.1;

echo -e "Cody has joined the channel1 channel.\nfull1 has joined the channel2 channel.\nfull2 has joined the channel2 channel.\nfull3 has joined the channel2 channel.\nfull4 has joined the channel2 channel.\nfull5 has joined the channel2 channel.\nHi channel 1\nCody has left the channel.\nfull6 has joined the channel2 channel.\nCody has joined the channel2 channel.\nHi channel 2" > server-capture-compare-messages;
echo -e "Welcome to the channel1 channel, Cody.\nCody has joined the channel.\nHi channel 1\nWelcome to the channel2 channel, Cody.\nYou are in the waiting queue and there are 1 user(s) ahead of you.\nYou are in the waiting queue and there are 0 user(s) ahead of you.\nCody has joined the channel.\nHi channel 2" > client-capture-compare-A;
echo -e "Welcome to the channel2 channel, full1.\nfull1 has joined the channel.\nfull2 has joined the channel.\nfull3 has joined the channel.\nfull4 has joined the channel.\nfull5 has joined the channel.\nfull6 has joined the channel.\nCody has joined the channel.\nHi channel 2" > client-capture-compare-B;

awk -F '] ' '{ print $2 }' server-capture   > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;

servermistakes=$(diff server-capture-messages server-capture-compare-messages       | wc -l);
clientmistakesa=$(diff client-capture-A-messages client-capture-compare-A  | wc -l);
clientmistakesb=$(diff client-capture-B-messages client-capture-compare-B  | wc -l);

clientmistakestot=$[clientmistakesa + clientmistakesb];

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
    fi
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

#rm goodconf *capture* 2> /dev/null;
