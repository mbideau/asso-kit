#!/bin/sh

# halt on first error
set -e

THIS_SCRIPT_DIR="`dirname "$0"`"

SHELL_FANCY="$THIS_SCRIPT_DIR"/lib/shell_fancy.sh
REDMINE_CONFIGURATION_FILE="$THIS_SCRIPT_DIR"/redmine.conf

SCRIPTS_DIR="$THIS_SCRIPT_DIR"/scripts
SCRIPT_SETUP_SYSTEM="$SCRIPTS_DIR"/setup_system.sh
SCRIPT_DEPLOY_SOURCE_CODE="$SCRIPTS_DIR"/deploy_redmine_source_code.sh
SCRIPT_DEPLOY_PLUGINS="$SCRIPTS_DIR"/deploy_plugins_and_theme.sh
SCRIPT_INSTALL_GITOLITE_AND_GIT_HOSTING="$SCRIPTS_DIR"/install_gitolite_and_plugin_git_hosting.sh

REDMINE_UPDATE_DEFAULT_DATA_SQL="$THIS_SCRIPT_DIR"/db/update_default_data.sql
MYSQL_ADMIN_CNF_FILE_PATH=/root/.config/mysql/admin.cnf

# shell fancy
. "$SHELL_FANCY"

# redmine dirs configuration
. "$REDMINE_CONFIGURATION_FILE"


title "Install Redmine and its plugins, plus Gitolite"

hepl()
{
	cat <<ENDCAT
This shell script install Redmine and ~25 plugins, plus Gitolite.

This :  
* install some required packages, including development tools like compilers
* create 2 users : one for Redmine, one for Gitolite
* create Mysql databases for Redmine user
* deploys the Redmine + plugins + theme source codes, and populate Mysql database
* configures everything

ENDCAT
}

# help
if [ "$#" = '0' -o "$1" = '-h' -o "$1" = '--help' ]
then
	help
	exit
fi

debug "Launching the system setup script"
"$SCRIPT_SETUP_SYSTEM" $*
 
debug "Copying the user deploy script and the configuration to redmine lib dir"
cp \
	"$SHELL_FANCY" \
	"$REDMINE_CONFIGURATION_FILE" \
	"$SCRIPT_DEPLOY_SOURCE_CODE" \
	"$SCRIPT_DEPLOY_PLUGINS" \
	"$REDMINE_UPDATE_DEFAULT_DATA_SQL" \
	"$REDMINE_LIB_DIR"/
chown "$REDMINE_FILES_OWNER:$REDMINE_FILES_GROUP" "$REDMINE_LIB_DIR"/*.sh "$REDMINE_LIB_DIR"/*.conf "$REDMINE_LIB_DIR"/*.sql
chmod +x "$REDMINE_LIB_DIR"/*.sh

debug "Launching user setup script '`basename "$SCRIPT_DEPLOY_SOURCE_CODE"`' ..."
su -c "$REDMINE_LIB_DIR"/"`basename "$SCRIPT_DEPLOY_SOURCE_CODE"`" "$REDMINE_USERNAME"

debug "Launching user setup script '`basename "$SCRIPT_DEPLOY_PLUGINS"`' ..."
su -c "$REDMINE_LIB_DIR"/"`basename "$SCRIPT_DEPLOY_PLUGINS"`" "$REDMINE_USERNAME"

debug "Launching system setup script '`basename "$SCRIPT_INSTALL_GITOLITE_AND_GIT_HOSTING"`' ..."
"$SCRIPT_INSTALL_GITOLITE_AND_GIT_HOSTING"

# cleanup
debug "Removing shell scripts and sql script from Redmine LIB dir"
rm -fr "$REDMINE_LIB_DIR"/*.sh "$REDMINE_LIB_DIR"/*.sql

debug "Removing the developments tools"
# apt-get purge -qq -y \
#	make g++ gcc cpp \
#	ruby-dev uuid-dev \
#	pkg-config build-essential cmake libgpg-error-dev

success "All done ... enjoy"

