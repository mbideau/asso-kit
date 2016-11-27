#!/bin/sh
# install a redmine instance

# @TODO : install mongrel and configure nginx to proxy pass to it

# halt on first error
set -e

SHELL_FANCY="`dirname "$0"`"/../lib/shell_fancy.sh
REDMINE_CONFIGURATION_FILE="`dirname "$0"`"/../redmine.conf
MYSQL_ADMIN_CNF_FILE_PATH=/root/.config/mysql/admin.cnf

# shell fancy
. "$SHELL_FANCY"

# redmine configuration
. "$REDMINE_CONFIGURATION_FILE"


title "Setup the system for a Redmine installation"

hepl()
{
	cat <<ENDCAT
This shell script setup the system for a Redmine installation

This :  
* install some required packages, including development tools like compilers
* create 2 users : one for Redmine, one for Gitolite

ENDCAT
usage
}

usage()
{
	cat <<ENDCAT
Usage:
	`basename "$0"`  MYSQL_ADMIN_PASSWORD_FILE  MYSQL_REDMINE_USERNAME  MYSQL_REDMINE_PASSWORD_FILE

Arguments:
	MYSQL_ADMIN_PASSWORD_FILE	A simple text file that contains Mysql Admin user password (/!\\ enter the same when asked)
	MYSQL_REDMINE_USERNAME		The Mysql Redmine user that will be created
	MYSQL_REDMINE_PASSWORD_FILE	A simple text file that contains Mysql Redmine user password
ENDCAT
}

if [ "$#" = '0' -o "$1" = '-h' -o "$1" = '--help' ]
then
	help
	exit
fi

mysql_admin_password_file="$1"
mysql_redmine_username="$2"
mysql_redmine_password_file="$3"
if [ $# -lt 3 ]
then
	error "missing arguments"
	usage
	exit 1
fi
if [ ! -f "$mysql_admin_password_file" ]
then
	error "file '$mysql_admin_password_file' doesn't exist"
	usage
	exit 1
fi
if [ "$mysql_redmine_username" = "" ]
then
	error "mysql redmine username can't be empty"
	usage
	exit 1
fi
if [ ! -f "$mysql_redmine_password_file" ]
then
	error "file '$mysql_redmine_password_file' doesn't exist"
	usage
	exit 1
fi

info "Installing required packages"

debug "Installing ruby language"
apt-get -qq -y install ruby ruby-dev

debug "Installing mysql database"
apt-get -qq -y install mysql-server mysql-client libmysqlclient-dev

debug "Installing ruby image library"
#apt-get -qq -yinstall pkg-config libmagickcore-dev libmagickwand-dev --no-install-recommends
# the line above require to install many X software, I won't allow that
# instead I have installed rmagick using apt: apt-get install ruby-rmagick
apt-get -qq -y install ruby-rmagick

debug "Installing make, gcc and g++ (to build somes ruby gems: ffi, xapian-full-alaveteli)"
apt-get -qq -y install make gcc g++

debug "Installing uuid-dev (required by the redmine DMSF plugin)"
apt-get -qq -y install uuid-dev

debug "Installed git (required to install most of the Redmine plugins)"
apt-get -qq -y install git

info "Creating Redmine user '$REDMINE_USERNAME'"
adduser --system --group --shell /bin/bash "$REDMINE_USERNAME" --home "$REDMINE_USER_HOME" --disabled-password >/dev/null

info "Creating Redmine directories"

debug "Creating Redmine LIB directory to '$REDMINE_LIB_DIR'"
mkdir "$REDMINE_LIB_DIR"
chown "$REDMINE_FILES_OWNER:$REDMINE_FILES_GROUP" "$REDMINE_LIB_DIR"
chmod ug+rw "$REDMINE_LIB_DIR"
chmod g+s "$REDMINE_LIB_DIR"

debug "Creating Redmine VAR directory to '$REDMINE_VAR_DIR'"
mkdir "$REDMINE_VAR_DIR"
chown "$REDMINE_FILES_OWNER:$REDMINE_FILES_GROUP" "$REDMINE_VAR_DIR"
chmod ug+rw "$REDMINE_VAR_DIR"
chmod g+s "$REDMINE_VAR_DIR"

debug "Created Redmine LOG directory to '$REDMINE_LOG_DIR'"
mkdir "$REDMINE_LOG_DIR"
chown "$REDMINE_FILES_OWNER:root" "$REDMINE_LOG_DIR" # using root for owner to prevent logrotate to throw a warning
chmod ug+rw "$REDMINE_LOG_DIR"
chmod g+s "$REDMINE_LOG_DIR"

info "Installing ruby gem dependencies manager 'bundler'"
gem install bundler >/dev/null

info "Setting up Mysql with a Redmine user and databases"

debug "Getting the mysql admin password"
mysql_admin_password="`head -n 1 "$mysql_admin_password_file"`"

debug "Generating a CNF file for admin user to : '$MYSQL_ADMIN_CNF_FILE_PATH'"
if [ ! -d "`dirname "$MYSQL_ADMIN_CNF_FILE_PATH"`" ]
then
	mkdir -p "`dirname "$MYSQL_ADMIN_CNF_FILE_PATH"`" -m "0750"
fi
cat > "$MYSQL_ADMIN_CNF_FILE_PATH" <<ENDCAT
[client]
host        = localhost
user        = "root"
password    = "$mysql_admin_password"
ENDCAT

debug "Getting the mysql redmine password"
mysql_redmine_password="`head -n 1 "$mysql_redmine_password_file"`"

debug "Creating a redmine user with its own database (with full permissions)"
mysql --defaults-extra-file="$MYSQL_ADMIN_CNF_FILE_PATH" <<ENDMYSQL
CREATE DATABASE redmine CHARACTER SET utf8;
CREATE DATABASE redmine_development CHARACTER SET utf8;
CREATE DATABASE redmine_test CHARACTER SET utf8;
CREATE USER '$mysql_redmine_username'@'localhost' IDENTIFIED BY '$mysql_redmine_password';
GRANT ALL PRIVILEGES ON redmine.* TO '$mysql_redmine_username'@'localhost';
GRANT ALL PRIVILEGES ON redmine_development.* TO '$mysql_redmine_username'@'localhost';
GRANT ALL PRIVILEGES ON redmine_test.* TO '$mysql_redmine_username'@'localhost';
ENDMYSQL

debug "Generating a mysql cnf file to '$REDMINE_MYSQL_CNF_FILE'"
cat > "$REDMINE_MYSQL_CNF_FILE" <<ENDCAT
[client]
host        = localhost
user        = "$mysql_redmine_username"
password    = "$mysql_redmine_password"
ENDCAT
chown "$REDMINE_FILES_OWNER:$REDMINE_FILES_GROUP" "$REDMINE_MYSQL_CNF_FILE"

