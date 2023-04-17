#!/bin/bash

rm goodconf *capture* 2> /dev/null

DEBUG=1;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf

timeout 1.5 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture &
sleep 0.4; timeout 1 bash -c "{ sleep 0.25; $(./decide.sh $1 client) $chan1port Marcus; }" > client-capture &
sleep 1.6;

echo "Marcus has joined the channel1 channel." > server-capture-compare;
echo -e "Welcome to the channel1 channel, Marcus.\nMarcus has joined the channel." > client-capture-compare;

stime=$(awk '{ print $3 }' server-capture);
ctime=$(head -n 1 client-capture | awk '{ print $3 }');

stimecut=${stime: 1: 6};
ctimecut=${ctime: 1: 6};
echo $stimecut;
echo $ctimecut;
now="$(date | awk '{ print $4 }')";
nowcut=${now: 0: 6};

if [ "$stimecut" = "$nowcut" ];
then
    echo -e "\033[0;32mServer timestamp matches current time.\033[0m";
else
    echo -e "\033[0;31mServer timestamp (${stimecut}x) does not match current time (${nowcut}x).\033[0m";
fi

if [ "$ctimecut" = "$nowcut" ];
then
    echo -e "\033[0;32mClient timestamp matches current time.\033[0m";
else
    echo -e "\033[0;31mClient timestamp (${ctimecut}x) does not match current time (${nowcut}x).\033[0m";
fi

awk -F '] ' '{ print $2 }' server-capture > server-capture-1;
awk -F '] ' '{ print $2 }' client-capture > client-capture-1;

servermistakes=$(diff server-capture-1 server-capture-compare | wc -l);
clientmistakes=$(diff client-capture-1 client-capture-compare | wc -l);

if [[ servermistakes -gt 0 ]]
then
    echo -e "\033[0;31mServer stdout does not match expected.\033[0m";
    if [[ DEBUG -eq 1 ]]
    then
        echo -e $(diff server-capture-1 server-capture-compare) 2>/dev/null;
    fi
else
    echo -e "\033[0;32mServer stdout matches expected.\033[0m";
fi

if [[ clientmistakes -gt 0 ]]
then
    echo -e "\033[0;31mClient stdout does not match expected.\033[0m";
    if [[ DEBUG -eq 1 ]]
    then
        echo -e $(diff server-capture-1 server-capture-compare) 2>/dev/null;
    fi
else
    echo -e "\033[0;32mClient stdout matches expected.\033[0m";
fi

rm goodconf server-capture server-capture-1 server-capture-compare client-capture client-capture-1 client-capture-compare 2> /dev/null
