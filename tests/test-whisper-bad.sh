#!/bin/bash

rm goodconf *capture* 2> /dev/null;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

DEBUG=1;
echo -en "channel channel1 $chan1port 10\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 3 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture &
sleep 0.2; timeout 2 bash -c "{ (sleep 0.9; echo '/whisper Chris You dont exist'; sleep 0.5; echo '/whisper Ula You dont exist either';) | $(./decide.sh $1 client) $chan1port Ronald; }" > client-capture-A &
sleep 0.3; timeout 2 bash -c "{ $(./decide.sh $1 client) $chan2port Chris; }" > client-capture-B &
sleep 3.1;

echo -e "Ronald has joined the channel1 channel.\nChris has joined the channel2 channel.\nYou dont exist\nYou dont exist either" > server-capture-compare-messages;
echo -e "[Server message\n[Server message\n[Ronald whispers to Chris:\n[Ronald whispers to Ula:" > server-capture-compare-names;
echo -e "Welcome to the channel1 channel, Ronald.\nRonald has joined the channel.\nChris is not here.\nUla is not here." > client-capture-compare-A;
echo -e "[Server message\n[Server message\n[Server message\n[Server message" > client-capture-compare-A-names;
echo -e "Welcome to the channel2 channel, Chris.\nChris has joined the channel." > client-capture-compare-B;

# Use a ton of escapes and suppress stderr to make awk stop complaining
awk -F ' \\\(' '{ print $1 }' server-capture > server-capture-names 2> /dev/null;
awk -F '] ' '{ print $2 }' server-capture > server-capture-messages;
awk -F ' \\\(' '{ print $1 }' client-capture-A > client-capture-A-names 2> /dev/null;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;

servermistakesn=$(diff server-capture-names server-capture-compare-names | wc -l);
servermistakesm=$(diff server-capture-messages server-capture-compare-messages | wc -l);
clientmistakesan=$(diff client-capture-A-names client-capture-compare-A-names | wc -l);
clientmistakesam=$(diff client-capture-A-messages client-capture-compare-A | wc -l);
clientmistakesb=$(diff client-capture-B-messages client-capture-compare-B | wc -l);

servermistakestot=$[servermistakesn + servermistakesm];
clientmistakestot=$[clientmistakesan + clientmistakesam + clientmistakesb];

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
