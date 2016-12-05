#!/bin/sh

# halt on first error
set -e

REDMINE_ENV_FILE="$HOME"/.config/redmine/environment.sh

. "$REDMINE_ENV_FILE"

environment="$1"
if [ "$environment" = "" ]
then
	environment=production
fi

cd "$REDMINE_LIB_DIR"/redmine


# be careful : binding to 0.0.0.0 will allow connection from the outside (not only localhost)
webserver_pid_file="$REDMINE_LIB_DIR"/redmine/tmp/pids/server.pid
webserver_pid="`if [ -f "$webserver_pid_file" ]; then head -n 1 "$webserver_pid_file"; fi`"
if [ "$webserver_pid" != '' ]
then
	if ! ps h -p $webserver_pid -o args|grep -q "ruby[0-9.]* bin/rails server webrick"
	then
		rm -f "$webserver_pid_file"
	fi
fi
webserver_pid="`if [ -f "$webserver_pid_file" ]; then head -n 1 "$webserver_pid_file"; fi`"
if [ "$webserver_pid" != '' ]
then
	echo "The webserver is already started with PID: $webserver_pid and environment: `ps h -p $webserver_pid -o args|grep -o '\--environment [a-z]\+'|sed 's/--environment //'`"
else
	bundle exec rails server webrick --environment "$environment" --binding=0.0.0.0 --daemon >/dev/null
fi
cd - >/dev/null
echo "Open your browser to : 'http://`hostname -I|sed 's/ //g'`:3000/'"
echo "Hit <enter> when you're done testing (it will stop the webserver) ..."
read cont
kill -15 `head -n 1 "$webserver_pid_file"`
exit 0

