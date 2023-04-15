# #!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;

chan1port=$[5000 + $RANDOM % 15000]
chan2port=$[20000 + $RANDOM % 15000]
chan3port=$[45000 + $RANDOM % 15000]

echo -en "channel channel1 $chan1port 5\nchannel channel2 $chan2port 10\nchannel channel3 $chan3port 10" > goodconf;

timeout 1.3 bash -c "{ $(./decide.sh $1 server) goodconf; }"                                                        > server-capture    &
timeout 1.2 bash -c "{ (sleep 0.3; echo '/list'; sleep 0.6; echo '/list') | $(./decide.sh $1 client) $chan1port Dan; }"   > client-capture    &
timeout 1.2 bash -c "{ sleep 0.1; $(./decide.sh $1 client) $chan1port Phil1; }"                                                      > /dev/null         &
timeout 0.6 bash -c "{ sleep 0.1; $(./decide.sh $1 client) $chan1port Phil2; }"                                                      > /dev/null         &
timeout 0.6 bash -c "{ sleep 0.1; $(./decide.sh $1 client) $chan1port Phil3; }"                                                      > /dev/null         &
timeout 0.6 bash -c "{ sleep 0.1; $(./decide.sh $1 client) $chan1port Phil4; }"                                                      > /dev/null         &
timeout 1.2 bash -c "{ sleep 0.1; $(./decide.sh $1 client) $chan1port Phil5; }"                                                      > /dev/null         &
timeout 1.2 bash -c "{ sleep 0.1; $(./decide.sh $1 client) $chan1port Phil6; }"                                                      > /dev/null         &
timeout 1.2 bash -c "{ sleep 0.1; $(./decide.sh $1 client) $chan2port Phil7; }"                                                      > /dev/null         &
timeout 1.2 bash -c "{ sleep 0.1; $(./decide.sh $1 client) $chan2port Phil8; }"                                                      > /dev/null         &
sleep 1.6;

# We didn't specify what happens if a connection 'just dies' so there is no exit message when the 0.6s clients time out. Whoops!
echo -e "Dan has joined the channel1 channel.\nPhil1 has joined the channel1 channel.\nPhil2 has joined the channel1 channel.\nPhil3 has joined the channel1 channel.\nPhil4 has joined the channel1 channel.\nPhil7 has joined the channel2 channel.\nPhil8 has joined the channel2 channel.\nPhil5 has joined the channel1 channel.\nPhil6 has joined the channel1 channel." > server-capture-compare;
echo -e "Welcome to the channel1 channel, Dan.\nDan has joined the channel.\nPhil1 has joined the channel.\nPhil2 has joined the channel.\nPhil3 has joined the channel.\nPhil4 has joined the channel.\nchannel1 5/5/2.\nchannel2 2/10/0.\nchannel3 0/10/0.\nPhil5 has joined the channel.\nPhil6 has joined the channel.\nchannel1 3/5/0.\nchannel2 2/10/0.\nchannel3 0/10/0." > client-capture-compare-messages;
echo -e "[Server message\n[Server message\n[Server message\n[Server message\n[Server message\n[Server message\n[Channel] channel1 5/5/2.\n[Channel] channel2 2/10/0.\n[Channel] channel3 0/10/0.\n[Server message\n[Server message\n[Channel] channel1 3/5/0.\n[Channel] channel2 2/10/0.\n[Channel] channel3 0/10/0." > client-capture-compare-names;

awk -F '] ' '{ print $2 }' server-capture > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture > client-capture-messages;
awk -F ' \\\(' '{ print $1 }' client-capture > client-capture-names 2> /dev/null;

servermistakes=$(diff server-capture-messages server-capture-compare            | wc -l);
clientmistakesm=$(diff client-capture-messages client-capture-compare-messages  | wc -l);
clientmistakesn=$(diff client-capture-names client-capture-compare-names        | wc -l);
clientmistakestot=$[clientmistakesm + clientmistakesn];

if [[ servermistakes -gt 0 ]]
then
    echo -e "\033[0;31mServer logs do not match expected.\033[0m";
    if [[ DEBUG -eq 1 ]]
    then
        echo -e $(diff server-capture-messages server-capture-compare) 2>/dev/null;
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

rm goodconf *capture* 2> /dev/null;
