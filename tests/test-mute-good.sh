#!/bin/bash

rm goodconf *capture* 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=1;
echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 7 bash -c "{ (sleep 1; echo '/mute channel1:Richard 2') | $(./decide.sh $1 server) goodconf; }" > server-capture &
sleep 0.3; timeout 5.5 bash -c "{ (sleep 0.5; echo -e 'A day may come when I am muted'; sleep 0.5; echo '/whisper Richard whisper whisper whisper'; sleep 2; echo -e 'And it was this day') | $(./decide.sh $1 client) $chan1port Richard; }" > client-capture &
sleep 7.1;

echo -e "Richard has joined the channel1 channel.\nA day may come when I am muted\nMuted Richard for 2 seconds.\nAnd it was this day" > server-capture-compare;
echo -e "[Server message\n[Richard\n[Server message\n[Richard" > server-capture-compare-names;
echo -e "Welcome to the channel1 channel, Richard.\nRichard has joined the channel.\nA day may come when I am muted\nYou have been muted for 2 seconds.\nYou are still muted for 1 seconds.\nAnd it was this day" > client-capture-compare-messages;

awk -F ' \\\(' '{ print $1 }' server-capture > server-capture-names 2> /dev/null;
awk -F '] ' '{ print $2 }' server-capture   > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture   > client-capture-messages;

servermistakesn=$(diff server-capture-names server-capture-compare-names | wc -l);
servermistakesm=$(diff server-capture-messages server-capture-compare | wc -l);
clientmistakes=$(diff client-capture-messages client-capture-compare-messages | wc -l);
servermistakestot=$[servermistakesm + servermistakesn];


if [[ servermistakestot -gt 0 ]]
then
    echo -e "\033[0;31mServer logs do not match expected.\033[0m";
    if [[ DEBUG -eq 1 ]]
    then
        echo -e $(diff server-capture-messages server-capture-compare) 2>/dev/null;
        echo ie $(diff server-capture-names server-capture-compare-names);
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

#rm goodconf *capture* 2> /dev/null;
