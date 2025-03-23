#!/bin/bash

echo "На случай если скрипты сломаются."
echo "ATTENTION!!!!!"
echo "Нельзя просто ввести '^M'"
echo "Надо нажать 'ctr+V' и потом нажать 'ctr+Enter'"
echo "Он напечатает '^M'"

echo "In case scripts get broken"
echo "ATTENTION!!!!!"
echo "No '^M'"
echo "Press 'ctr+V' & 'ctr+Enter'"
echo "It will print '^M'"


com="$@"

if (( $# < 1 )); then
	echo "Бивень, надо так:"
	echo "$0 sed -i 's/^M$//g'"
	exit 1
fi

for file in `ls ./`; do
    $com ./$file
done

echo "done"

exit 0