#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;
echo -en "channel channel1 1246 10\nchannel channel2 2357 10\nchannel channel3 3468 10" > goodconf;

timeout 2.1 bash -c "{ (sleep 0.3; echo '/mute channel1:Richard 1') | $(./decide.sh $1 server) goodconf; }" > server-capture &
timeout 2 bash -c "{ (sleep 1; echo 'A day may come when I am muted'; echo '/whisper Richard whisper whisper whisper'; sleep 0.6; echo 'And it was this day') | $(./decide.sh $1 client) 1234 Richard; }" > client-capture;

sleep 2.2;

echo -e "Richard has joined the channel1 channel.\nMuted Richard for 1 seconds.\nAnd it was this day" > server-capture-compare;
echo -e "Welcome to the channel1 channel, Richard.\nRichard has joined the channel.\nYou have been muted for 1 seconds.\nYou are still muted for 1 seconds.\nYou are still muted for 1 seconds.\nAnd it was this day" > client-capture-compare-messages;

awk -F '] ' '{ print $2 }' server-capture   > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture   > client-capture-messages;

servermistakes=$(diff server-capture-messages server-capture-compare | wc -l);
clientmistakes=$(diff client-capture-messages client-capture-compare-messages | wc -l);

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

if [[ clientmistakes -gt 0 ]]
then
    echo -e "\033[0;31mClients' message logs do not match expected.\033[0m";
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
