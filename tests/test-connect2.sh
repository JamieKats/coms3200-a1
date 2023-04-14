#!/bin/bash

rm server-capture server-capture-1 server-capture-compare client-capture-A client-capture-B client-capture-compare-A client-capture-compare-B client-capture-A-1 client-capture-B-1 names-A names-B names-S names-compare goodconf 2> /dev/null;

echo -en "channel channel1 1236 10\nchannel channel2 2347 10\nchannel channel3 3458 10" > goodconf;

timeout 3 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture                                 &
timeout 4 bash -c "{ (sleep 1; echo 'Hi Tom') | $(./decide.sh $1 client) 1234 Arthur; }" > client-capture-A &
timeout 4 bash -c "{ (sleep 2; echo 'Hi Arthur') | $(./decide.sh $1 client) 1234 Tom; }" > client-capture-B ;

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
        echo -e $(diff server-capture-messages server-capture-compare-messages) 2>/dev/null;
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

rm server-capture server-capture-1 server-capture-compare client-capture-A client-capture-B client-capture-compare-A client-capture-compare-B client-capture-A-1 client-capture-B-1 names-A names-B names-S names-compare goodconf 2> /dev/null
