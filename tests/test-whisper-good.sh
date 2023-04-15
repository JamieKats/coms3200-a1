#!/bin/bash

rm goodconf *capture* 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=1;
echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 2 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture &
timeout 1.5 bash -c "{ (sleep 0.5; echo '/whisper Matthew Hi Matthew') | $(./decide.sh $1 client) $chan1port Austin; }" > client-capture-A &
timeout 1.5 bash -c "{ (sleep 1; echo '/whisper Austin Hi Austin') | $(./decide.sh $1 client) $chan1port Matthew; }" > client-capture-B &
timeout 1.5 bash -c "{ sleep 0.15; $(./decide.sh $1 client) $chan1port Arnold; }" > client-capture-C &
sleep 2.1;

echo -e "Austin has joined the channel1 channel.\nMatthew has joined the channel1 channel.\nArnold has joined the channel1 channel.\nHi Matthew\nHi Austin" > server-capture-compare-messages;
echo -e "[Server message\n[Server message\n[Server message\n[Austin whispers to Matthew:\n[Matthew whispers to Austin:" > server-capture-compare-names;
echo -e "Welcome to the channel1 channel, Austin.\nAustin has joined the channel.\nMatthew has joined the channel.\nArnold has joined the channel.\nHi Austin" > client-capture-compare-A-messages;
echo -e "[Server message\n[Server message\n[Server message\n[Server message\n[Matthew whispers to you:" > client-capture-compare-A-names;

echo -e "Welcome to the channel1 channel, Matthew.\nMatthew has joined the channel.\nArnold has joined the channel.\nHi Matthew" > client-capture-compare-B-messages;
echo -e "[Server message\n[Server message\n[Server message\n[Austin whispers to you:" > client-capture-compare-B-names;

echo -e "Welcome to the channel1 channel, Arnold.\nArnold has joined the channel." > client-capture-compare-C;

# 2> /dev/null everywhere to make awk stop complaining about regex silliness
awk -F '] ' '{ print $2 }' server-capture > server-capture-messages;
awk -F ' \\\(' '{ print $1 }' server-capture > server-capture-names 2> /dev/null;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F ' \\\(' '{ print $1 }' client-capture-A> client-capture-A-names 2> /dev/null;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;
awk -F ' \\\(' '{ print $1 }' client-capture-B > client-capture-B-names 2> /dev/null;
awk -F '] ' '{ print $2 }' client-capture-C > client-capture-C-messages;

# Have to check names here because of the text in the [] tags changes a bit with /whisper
servermistakesm=$(diff server-capture-messages server-capture-compare-messages | wc -l);
servermistakesn=$(diff server-capture-names server-capture-compare-names | wc -l);
clientmistakesam=$(diff client-capture-A-messages client-capture-compare-A-messages | wc -l);
clientmistakesan=$(diff client-capture-A-names client-capture-compare-A-names | wc -l);
clientmistakesbm=$(diff client-capture-B-messages client-capture-compare-B-messages | wc -l);
clientmistakesbn=$(diff client-capture-B-names client-capture-compare-B-names | wc -l);
clientmistakesc=$(diff client-capture-C-messages client-capture-compare-C | wc -l);

servermistakestot=$[servermistakesm + servermistakesn];
clientmistakestot=$[clientmistakesan + clientmistakesam + clientmistakesbn + clientmistakesbm + clientmistakesc];

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
        echo -e "$(diff client-capture-A-names client-capture-compare-A-names)"  2>/dev/null;
        echo -e "$(diff client-capture-A-messages client-capture-compare-A-messages)" 2>/dev/null;
        echo -e "--------";
        echo -e "Client B"
        echo -e "--------";
        echo -e "$(diff client-capture-B-names client-capture-compare-B-names)"  2>/dev/null;
        echo -e "$(diff client-capture-B-messages client-capture-compare-B-messages)"  2>/dev/null;
        echo -e "--------";
        echo -e "Client C";
        echo -e "--------";
        echo -e "$(diff client-capture-C-names client-capture-compare-C-names)"  2>/dev/null;
        echo -e "$(diff client-capture-C-messages client-capture-compare-C-messages)"  2>/dev/null;
        echo -e "--------";
    fi
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
