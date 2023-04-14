#!/bin/bash

test=".sh";
comm="#";

clear;

if [ "$1" = "" ];
then
    echo -e "\033[0;31mSpecify the solution directory.\033[0m"
else
    while read -r line;
    do
        first=$(echo $line | awk '{ print $1 }');
        head=${first: 0: 1};
        ext=${first: -3};
        if [ "$head" != "$comm" ];
        then
           
            if [ "$ext" = "$test" ];
            then
                echo -e "\e[38;5;226m$first:\e[38;5;255m";
                rm goodconf *capture*   2> /dev/null;
                ./$first $1             2> /dev/null;
                rm goodconf *capture*   2> /dev/null;
            else
                 echo $first;
            fi
        fi

    done < list;
fi
