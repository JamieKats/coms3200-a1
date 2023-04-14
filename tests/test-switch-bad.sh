#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;
echo -en "channel channel1 1258 10\nchannel channel2 2369 10\nchannel channel3 3480 10" > goodconf;

timeout 1.3 bash -c "{ $(./decide.sh $1 server) goodconf; }"    > server-capture &
timeout 1.2 bash -c "{ (sleep 0.3; echo 'I am in channel 1'; sleep 0.3; echo '/switch nonexist'; sleep 0.3; echo 'I am in channel 1') | $(./decide.sh $1 client) 1234 Slim; }" > client-capture-A &
timeout 1.2 bash -c "{ $(./decide.sh $1 client) 1234 Shady; }"  > client-capture-B;

sleep 1.4;

echo -e "Slim has joined the channel1 channel.\nShady has joined the channel1 channel.\nI am in channel 1\nI am in channel 1" > server-capture-compare-messages;
echo -e "Welcome to the channel1 channel, Slim.\nSlim has joined the channel.\nShady has joined the channel.\nI am in channel 1\nnonexist does not exist.\nI am in channel 1"   > client-capture-compare-A-messages;
echo -e "Welcome to the channel1 channel, Shady.\nShady has joined the channel.\nI am in channel 1\nI am in channel 1" > client-capture-compare-B-messages;

awk -F '] ' '{ print $2 }' server-capture   > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;

servermistakes=$(diff server-capture-messages server-capture-compare-messages       | wc -l);
clientmistakesa=$(diff client-capture-A-messages client-capture-compare-A-messages  | wc -l);
clientmistakesb=$(diff client-capture-B-messages client-capture-compare-B-messages  | wc -l);

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
