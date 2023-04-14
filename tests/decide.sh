#!/bin/bash
CORP=$(ls $1 | grep '\.c' | wc -l);
if [[ CORP -gt 0 ]]
then
    CMD="$1/chat$2 ";
else
    CMD="python3 $1/chat$2.py ";
fi

echo $CMD;
