#!/bin/bash

FORKS=$(grep 'fork(' $1/* | wc -l);
SELECTS=$(grep 'select(' $1/* | wc -l);
POLLS=$(grep 'poll(' $1/* | wc -l);
TOT=$[FORKS + SELECTS];
if [[ TOT -gt 0 ]]
then
    echo -e "\033[0;31mIllegal syscalls detected";
    echo "$(grep 'fork(' $1/*)";
    echo "$(grep 'select(' $1/*)";
    echo "$(grep 'poll(' $1/*)";
else
    echo -e "\033[0;32mNo illegal syscalls detected";
fi

echo -en '\033[0m'
