#!/bin/sh

for x in doc/ri/* doc/smm/*.wix doc/ri/*
do 
	if test -f $x
	then
		(echo update faq | ci -l $x; echo " ")
	fi
done

exit 0
