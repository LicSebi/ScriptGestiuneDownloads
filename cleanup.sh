#!/bin/bash

echo "curatare mediu de testare"

rm -rf Downloads Media

echo "apelam scriptul de generare a datelor de test"

if [ -f "./date_test.sh" ]; then
    bash ./date_test.sh
else
    echo "!!! scriptul nu a fost gasit"
    exit 1
fi

echo "resetare complet"
