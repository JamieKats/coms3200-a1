#!/bin/bash

rm goodconf *capture* 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=1;
echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 3 bash -c "{ $(./decide.sh $1 server) goodconf; }"    > server-capture &
sleep 0.2; timeout 2 bash -c "{ (sleep 0.6; echo 'I am in channel 1'; sleep 0.3; echo '/switch nonexist'; sleep 0.3; echo 'I am in channel 1') | $(./decide.sh $1 client) $chan1port Slim; }" > client-capture-A &
sleep 0.3; timeout 2 bash -c "{ $(./decide.sh $1 client) $chan1port Shady; }"  > client-capture-B &
sleep 3.1;

echo -e "Slim has joined the channel1 channel.\nShady has joined the channel1 channel.\nI am in channel 1\nI am in channel 1" > server-capture-compare-messages;
echo -e "Welcome to the channel1 channel, Slim.\nSlim has joined the channel.\nShady has joined the channel.\nI am in channel 1\nnonexist does not exist.\nI am in channel 1"   > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, Shady.\nShady has joined the channel.\nI am in channel 1\nI am in channel 1" > client-capture-compare-B;

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

rm goodconf *capture* 2> /dev/null;
