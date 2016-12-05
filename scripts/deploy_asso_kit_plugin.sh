#!/bin/sh
# deploy asso kit plugin

# halt on first error
set -e

THIS_SCRIPT_DIR="`dirname "$0"`"
SRC_ROOT="`dirname "$THIS_SCRIPT_DIR"|xargs realpath`"

SHELL_FANCY="$SRC_ROOT"/lib/shell_fancy.sh
CONFIGURATION_FILE="$SRC_ROOT"/redmine.conf

REDMINE_UPDATE_DEFAULT_DATA_SQL="$SRC_ROOT"/db/update_default_data_asso_kit.sql

# redmine configuration
. "$CONFIGURATION_FILE"

REDMINE_MYSQL_CNF_FILE=$REDMINE_USER_HOME/.config/mysql/redmine.cnf

REDMINE_TEST_SCRIPT_PATH="$REDMINE_USER_HOME"/bin/test_redmine_with_webrick_webserver.sh

# shell fancy
. "$SHELL_FANCY"

title "Deploy asso kit plugin"

help()
{
	cat <<ENDCAT
This shell script deploys asso kit plugin
ENDCAT
usage
}

usage()
{
	cat <<ENDCAT
Usage:
	`basename "$0"`  ENVIRONMENT

Arguments:
	ENVIRONMENT	  The environment to deploy to (defautl: production)
				  Can be: production, test, development

ENDCAT
}

# help
if [ "$1" = '-h' -o "$1" = '--help' ]
then
	help
	exit
fi

# arguments
environment="$1"
if [ "$environment" = "" ]
then
	environment="production"
fi

debug "Moving the current dir to the redmine current LIB dir"
redmine_current_lib_dir="$REDMINE_LIB_DIR"/redmine
cd "$redmine_current_lib_dir"


info "Deploying redmine plugin Asso Kit"
debug "Installing asso_kit from dir"
su -c "git clone -q https://github.com/mbideau/redmine-asso-kit.git plugins/zz_asso_kit" $REDMINE_USERNAME
su -c "bundle install --without development test --path vendor/bundle" $REDMINE_USERNAME >/dev/null
su -c "bundle exec rake redmine:plugins NAME=zz_asso_kit RAILS_ENV=$environment" $REDMINE_USERNAME >/dev/null


info "Updating default data"
debug "Updating default data with our custom SQL script"
mysql --defaults-extra-file="$REDMINE_MYSQL_CNF_FILE" "$REDMINE_MYSQL_DATABASE_PRODUCTION" < "$REDMINE_UPDATE_DEFAULT_DATA_SQL"


if [ "$DEPLOY_NGINX_PASSENGER" = 'true' ]
then
	info "Restarting webserver (nginx)"
	service nginx restart
fi

