#!/bin/bash

rm goodconf *capture* 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=0;
echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 1.3 bash -c "{ $(./decide.sh $1 server) goodconf; }"        > server-capture    &
timeout 1.2 bash -c "{ (sleep 0.3; echo 'I am in channel 1'; sleep 0.3; echo '/switch channel2'; sleep 0.3; echo 'I am in channel 2') | $(./decide.sh $1 client) $chan1port Alex; }" > client-capture-A &
timeout 1.2 bash -c "{ sleep 0.15; $(./decide.sh $1 client) $chan1port Marshall; }"   > client-capture-B  &
timeout 1.2 bash -c "{ sleep 0.15; $(./decide.sh $1 client) $chan2port Kimmel; }"     > client-capture-C &
sleep 1.4;

echo -e "Alex has joined the channel1 channel.\nMarshall has joined the channel1 channel.\nKimmel has joined the channel2 channel.\nI am in channel 1\nAlex has left the channel.\nAlex has joined the channel2 channel.\nI am in channel 2" > server-capture-compare-messages;
echo -e "Welcome to the channel1 channel, Alex.\nAlex has joined the channel.\nMarshall has joined the channel.\nI am in channel 1\nWelcome to the channel2 channel, Alex.\nAlex has joined the channel.\nI am in channel 2"                > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, Marshall.\nMarshall has joined the channel.\nI am in channel 1\nAlex has left the channel."   > client-capture-compare-B;
echo -e "Welcome to the channel2 channel, Kimmel.\nKimmel has joined the channel.\nAlex has joined the channel.\nI am in channel 2"     > client-capture-compare-C;

awk -F '] ' '{ print $2 }' server-capture   > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;
awk -F '] ' '{ print $2 }' client-capture-C > client-capture-C-messages;

servermistakes=$(diff server-capture-messages server-capture-compare-messages       | wc -l);
clientmistakesa=$(diff client-capture-A-messages client-capture-compare-A  | wc -l);
clientmistakesb=$(diff client-capture-B-messages client-capture-compare-B  | wc -l);
clientmistakesc=$(diff client-capture-C-messages client-capture-compare-C           | wc -l);

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
    fi
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
