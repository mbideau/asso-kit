#!/bin/sh

title()
{
	echo "### $1 ###"
}

debug()
{
	if [ "$DEBUG" = 'true' ]
	then
		echo "--- [`date '+%H:%M:%S'`]  DEBUG  $1"
	fi
}

info()
{
	echo "--- [`date '+%H:%M:%S'`]  INFO  $1"
}

warning()
{
	echo "--- [`date '+%H:%M:%S'`]  WARNING $1" >&2
}

error()
{
	echo "--- [`date '+%H:%M:%S'`]  ERROR $1" >&2
}

code()
{
	echo "$1"|sed "s/^/$2$> /g"
}

user_action()
{
	echo "--- USER ACTION REQUIRED : $1"
}

