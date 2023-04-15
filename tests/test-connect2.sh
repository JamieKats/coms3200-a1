#!/bin/bash

rm server-capture server-capture-1 server-capture-compare client-capture-A client-capture-B client-capture-compare-A client-capture-compare-B client-capture-A-1 client-capture-B-1 names-A names-B names-S names-compare goodconf 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=1;

echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 3 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture &
timeout 2.9 bash -c "{ (sleep 0.75; echo -e 'Hi Tom') | $(./decide.sh $1 client) $chan1port Arthur; }" > client-capture-A &
timeout 2.9 bash -c "{ (sleep 1; echo -e 'Hi Arthur') | $(./decide.sh $1 client) $chan1port Tom; }" > client-capture-B  &
sleep 3.1;

echo -e "Arthur has joined the channel1 channel.\nTom has joined the channel.\nHi Tom\nHi Arthur" > server-capture-compare;
echo -e "Welcome to the channel1 channel, Arthur.\nArthur has joined the channel.\nTom has joined the channel.\nHi Tom\nHi Arthur" > client-capture-compare-A;
echo -e "Welcome to the channel1 channel, Tom.\nTom has joined the channel.\nHi Tom\nHi Arthur" > client-capture-compare-B;

echo -e "[Arthur\n[Tom" > names-compare;

awk -F '] ' '{ print $2 }' server-capture > server-capture-1;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-1;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-1;

tail -n 2 client-capture-A | awk '{ print $1 }' > names-A;
tail -n 2 client-capture-B | awk '{ print $1 }' > names-B;
tail -n 2 server-capture | awk '{ print $1 }' > names-S;

servermistakes=$(diff server-capture-1 server-capture-compare | wc -l);
clientmistakes1=$(diff client-capture-A-1 client-capture-compare-A | wc -l);
clientmistakes2=$(diff client-capture-B-1 client-capture-compare-B | wc -l);
clientmistakestot=$[clientmistakes1 + clientmistakes2];

serverbadnames=$(diff names-S names-compare | wc -l);
clientbadnamesA=$(diff names-A names-compare | wc -l);
clientbadnamesB=$(diff names-B names-compare | wc -l);
clientbadnamestot=$[clientbadnamesA + clientbadnamesB];

if [[ servermistakes -gt 0 ]]
then
    echo -e "\033[0;31mServer logs do not match expected.\033[0m";
    if [[ DEBUG -eq 1 ]]
    then
        echo -e $(diff server-capture-1 server-capture-compare) 2>/dev/null;
        echo -e $(diff names-S names-compare) 2>/dev/null;
    fi
else
    echo -e "\033[0;32mServer logs match expected.\033[0m";
fi

if [[ clientmistakestot -gt 0 ]]
then
    echo -e "\033[0;31mClients' message logs do not match expected.\033[0m";
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

if [[ serverbadnames -gt 0 ]]
then
    echo -e "\033[0;31mWrong names attached to serverside message log.\033[0m";
else
    echo -e "\033[0;32mCorrect names attached to serverside message log.\033[0m";
fi

if [[ clientbadnamestot -gt 0 ]]
then
    echo -e "\033[0;31mWrong names attached to clientside message log(s).\033[0m";
    cat names-A
    echo
    cat names-B
else
    echo -e "\033[0;32mCorrect names attached to clientside message log(s).\033[0m";
fi

#rm server-capture server-capture-1 server-capture-compare client-capture-A client-capture-B client-capture-compare-A client-capture-compare-B client-capture-A-1 client-capture-B-1 names-A names-B names-S names-compare goodconf 2> /dev/null
