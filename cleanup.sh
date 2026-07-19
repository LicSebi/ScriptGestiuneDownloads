#!/bin/bash

rm -rf Downloads Media

if [ -f "./date_test.sh" ]; then
    bash ./date_test.sh
else
    echo "!!! Scriptul de generare teste nu a fost gasit"
    exit 1
fi

echo "Resetarea mediului de testare completa"
