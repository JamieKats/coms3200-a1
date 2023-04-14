#!/bin/bash

rm goodconf *capture* 2> /dev/null;

DEBUG=0;
echo -en "channel channel1 1249 10\nchannel channel2 2360 10\nchannel channel3 3471 10" > goodconf;

timeout 1 bash -c "{ $(./decide.sh $1 server) goodconf; }" > server-capture &
timeout 0.5 bash -c "{ $(./decide.sh $1 client) 1249 Sam; }" > client-capture-A &
timeout 0.7 bash -c "{ sleep 0.2; $(./decide.sh $1 client) 1249 Sam; }" > client-capture-B;

sleep 1.1;

echo -e "Sam has joined the channel1 channel." > server-capture-compare;
echo -e "Welcome to the channel1 channel, Sam.\nSam has joined the channel." > client-capture-compare-A;
echo -e "Server message (time)] Cannot connect to the channel1 channel." > client-capture-compare-B;

# 2> /dev/null everywhere to make awk stop complaining about regex silliness
awk -F '] ' '{ print $2 }' server-capture > server-capture-messages;
awk -F '] ' '{ print $2 }' client-capture-A > client-capture-A-messages;
awk -F '] ' '{ print $2 }' client-capture-B > client-capture-B-messages;

servermistakes=$(diff server-capture-messages server-capture-compare | wc -l);
clientmistakesa=$(diff client-capture-A-messages client-capture-compare-A | wc -l);
clientmistakesbm=$(diff client-capture-B-messages client-capture-compare-B | wc -l);

clientmistakestot=$[clientmistakesa + clientmistakesb];

if [[ servermistakestot -gt 0 ]]
then
    echo -e "\033[0;31mServer logs do not match expected.\033[0m";
#     cat server-capture
#     echo
#     cat server-capture-names
#     echo
#     cat server-capture-compare-names
#     echo '---'
#     cat server-capture-messages
#     echo
#     cat server-capture-compare-messages
else
    echo -e "\033[0;32mServer logs match expected.\033[0m";
fi

if [[ clientmistakestot -gt 0 ]]
then
    echo -e "\033[0;31mClients' message logs do not match expected.\033[0m";
#     echo $clientmistakesbn $clientmistakesbm
#     cat client-capture-B
#     echo
#     cat client-capture-compare-B-names
#     echo
#     cat client-capture-B-names
else
    echo -e "\033[0;32mClients' message logs match expected.\033[0m";
fi

rm goodconf *capture* 2> /dev/null;
