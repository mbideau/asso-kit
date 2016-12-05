#!/bin/sh
# setup the system for the Asso Kit installation

# halt on first error
set -e

THIS_SCRIPT_DIR="`dirname "$0"`"
SHELL_FANCY="$THIS_SCRIPT_DIR"/../lib/shell_fancy.sh
CONFIGURATION_FILE="$THIS_SCRIPT_DIR"/../redmine.conf
MYSQL_ADMIN_CNF_FILE_PATH=/root/.config/mysql/admin.cnf

# shell fancy
. "$SHELL_FANCY"

# redmine environment
. "$CONFIGURATION_FILE"

REDMINE_ENV_FILE_="$REDMINE_USER_HOME"/.config/redmine/environment.sh
MYSQL_REDMINE_CNF_FILE_PATH="$REDMINE_USER_HOME"/.config/mysql/redmine.cnf

title "Setup the system for a Redmine installation"

help()
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
	`basename "$0"`  MYSQL_ADMIN_PASSWORD_FILE  MYSQL_REDMINE_PASSWORD_FILE

Arguments:
	MYSQL_ADMIN_PASSWORD_FILE	A simple text file that contains Mysql Admin user password
	MYSQL_REDMINE_PASSWORD_FILE	A simple text file that contains Mysql Redmine user password

ENDCAT
}

if [ "$#" = '0' -o "$1" = '-h' -o "$1" = '--help' ]
then
	help
	exit
fi


mysql_admin_password_file="$1"
mysql_redmine_password_file="$2"
if [ $# -lt 2 ]
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
if [ ! -f "$mysql_redmine_password_file" ]
then
	error "file '$mysql_redmine_password_file' doesn't exist"
	usage
	exit 1
fi


if [ "$DEPLOY_NGINX_PASSENGER" = 'true' ]
then
	if ! lsb_release -cs|grep -q 'wheezy\|jessie\|precise\|trusty\|xenial'
	then
		error "The nginx + phusion-passenger is only available for the following releases :
Debian: wheezy  | jessie
Ubutun: precise | trusty | xenial
"
		error "To disable the deployment of nginx + phusion-passenger, change the variable DEPLOY_NGINX_PASSENGER to 'false', in '$CONFIGURATION_FILE'"
		exit 1
	fi
fi

info "Installing required packages (please be patient ...)"

if [ "$DEPLOY_NGINX_PASSENGER" = 'true' ]
then
	debug "Adding phusion-passenger repository"
	apt-key adv --quiet --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7 >/dev/null
	apt-get -qq -y install apt-transport-https ca-certificates >/dev/null
	echo deb https://oss-binaries.phusionpassenger.com/apt/passenger `lsb_release -cs` main > /etc/apt/sources.list.d/passenger.list
fi

debug "Updating APT"
apt-get -qq update >/dev/null

info " - wget tar gzip bzip2 unzip xz (to download and uncompress somes files)"
apt-get -qq -y install --no-install-recommends wget tar gzip bzip2 unzip xz-utils >/dev/null

info " - ruby language"
apt-get -qq -y install --no-install-recommends ruby ruby-dev >/dev/null

if [ "$DEPLOY_NGINX_PASSENGER" = 'true' ]
then
	info " - nginx and phusion-passenger"
	apt-get -qq -y install --no-install-recommends nginx-extras passenger >/dev/null
	if [ ! -e /etc/nginx/conf.d/passenger.conf ]
	then
		if [ -f /etc/nginx/passenger.conf ]
		then
			mv /etc/nginx/passenger.conf /etc/nginx/conf.d/
		else
			echo -e "passenger_root /usr/lib/ruby/vendor_ruby/phusion_passenger/locations.ini;\npassenger_ruby /usr/bin/passenger_free_ruby;" > /etc/nginx/conf.d/passenger.conf
		fi
	fi
	if ! grep -q 'passenger_env_var PATH' /etc/nginx/conf.d/passenger.conf
	then
		echo 'passenger_env_var PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin;' >> /etc/nginx/conf.d/passenger.conf
	fi
	service nginx restart
	debug "Checking phusion-passenger installation"
	/usr/bin/passenger-config validate-install --auto --no-summary
	passenger_stats_tmp=`mktemp '/tmp/passenger.stats.tmp.XXXXXXXXXX'`
	/usr/sbin/passenger-memory-stats > "$passenger_stats_tmp" 2>/dev/null
	if ! grep -q 'nginx: master process' "$passenger_stats_tmp" || ! grep -q 'Passenger core' "$passenger_stats_tmp"
	then
		rm -f "$passenger_stats_tmp"
		error "The nginx + phusion-passenger installation seems not to be functionnal"
		user_action "You should check it before continuing. Use following commands :"
		code "/usr/bin/passenger-config validate-install"
		code "/usr/sbin/passenger-memory-stats"
		user_action "Hit <enter> when the situation is settled, or CTRL-C to abort installation"
		read cont
	fi
	rm -f "$passenger_stats_tmp"
fi

info " - mysql client"
apt-get -qq -y install --no-install-recommends mysql-client libmysqlclient-dev >/dev/null

info " - mysql server"
echo "mysql-server mysql-server/root_password password `head -n 1 "$mysql_admin_password_file"`" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password `head -n 1 "$mysql_admin_password_file"`" | debconf-set-selections
apt-get -qq -y install --no-install-recommends mysql-server >/dev/null

info " - ruby image library"
#apt-get -qq -yinstall pkg-config libmagickcore-dev libmagickwand-dev --no-install-recommends
# the line above require to install many X software, I won't allow that
# instead I have installed rmagick using apt: apt-get install ruby-rmagick
apt-get -qq -y install --no-install-recommends ruby-rmagick >/dev/null

info " - make, gcc and g++ (to build somes ruby gems)"
apt-get -qq -y install --no-install-recommends make gcc g++ >/dev/null

info " - uuid-dev (required by the redmine DMSF plugin)"
apt-get -qq -y install --no-install-recommends uuid-dev >/dev/null

info " - git (to get the sources code of Redmine plugins)"
apt-get -qq -y install --no-install-recommends git >/dev/null


info "Creating Redmine user '$REDMINE_USERNAME'"
adduser --system --group --shell /bin/bash "$REDMINE_USERNAME" --home "$REDMINE_USER_HOME" --disabled-password >/dev/null


info "Creating Redmine directories"

info " - $REDMINE_LIB_DIR"
debug "Creating Redmine LIB directory to '$REDMINE_LIB_DIR'"
mkdir "$REDMINE_LIB_DIR"
chown "$REDMINE_FILES_OWNER:$REDMINE_FILES_GROUP" "$REDMINE_LIB_DIR"
chmod ug+rw "$REDMINE_LIB_DIR"
chmod g+s "$REDMINE_LIB_DIR"

info " - $REDMINE_VAR_DIR"
debug "Creating Redmine VAR directory to '$REDMINE_VAR_DIR'"
mkdir "$REDMINE_VAR_DIR"
chown "$REDMINE_FILES_OWNER:$REDMINE_FILES_GROUP" "$REDMINE_VAR_DIR"
chmod ug+rw "$REDMINE_VAR_DIR"
chmod g+s "$REDMINE_VAR_DIR"

info " - $REDMINE_LOG_DIR"
debug "Created Redmine LOG directory to '$REDMINE_LOG_DIR'"
mkdir "$REDMINE_LOG_DIR"
chown "$REDMINE_FILES_OWNER:root" "$REDMINE_LOG_DIR" # using root for owner to prevent logrotate to throw a warning
chmod ug+rw "$REDMINE_LOG_DIR"
chmod g+s "$REDMINE_LOG_DIR"


info "Creating a redmine environment file to '$REDMINE_ENV_FILE_'"

if [ ! -d "`dirname "$REDMINE_ENV_FILE_"`" ]
then
	debug "Creating directory '`dirname "$REDMINE_ENV_FILE_"`'"
	mkdir -p "`dirname "$REDMINE_ENV_FILE_"`"
	chown "$REDMINE_FILES_OWNER":"$REDMINE_FILES_GROUP" "`dirname "$REDMINE_ENV_FILE_"`"
fi
debug "Copying the redmine configuration to '$REDMINE_ENV_FILE_'"
cp "$CONFIGURATION_FILE" "$REDMINE_ENV_FILE_"
chown "$REDMINE_FILES_OWNER":"$REDMINE_FILES_GROUP" "$REDMINE_ENV_FILE_"


info "Installing ruby gem dependencies manager 'bundler'"
gem install bundler >/dev/null


info "Setting up Mysql with user '$REDMINE_MYSQL_USERNAME' and databases ($REDMINE_MYSQL_DATABASE_PRODUCTION, $REDMINE_MYSQL_DATABASE_TEST, $REDMINE_MYSQL_DATABASE_DEV)"

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
CREATE DATABASE $REDMINE_MYSQL_DATABASE_PRODUCTION CHARACTER SET utf8;
CREATE DATABASE $REDMINE_MYSQL_DATABASE_TEST CHARACTER SET utf8;
CREATE DATABASE $REDMINE_MYSQL_DATABASE_DEV CHARACTER SET utf8;
CREATE USER '$REDMINE_MYSQL_USERNAME'@'localhost' IDENTIFIED BY '$mysql_redmine_password';
GRANT ALL PRIVILEGES ON ${REDMINE_MYSQL_DATABASE_PRODUCTION}.* TO '$REDMINE_MYSQL_USERNAME'@'localhost';
GRANT ALL PRIVILEGES ON ${REDMINE_MYSQL_DATABASE_TEST}.* TO '$REDMINE_MYSQL_USERNAME'@'localhost';
GRANT ALL PRIVILEGES ON ${REDMINE_MYSQL_DATABASE_DEV}.* TO '$REDMINE_MYSQL_USERNAME'@'localhost';
ENDMYSQL

if [ ! -d "`dirname "$MYSQL_REDMINE_CNF_FILE_PATH"`" ]
then
	debug "Creating directory '`dirname "$MYSQL_REDMINE_CNF_FILE_PATH"`'"
	mkdir -p "`dirname "$MYSQL_REDMINE_CNF_FILE_PATH"`"
	chown "$REDMINE_FILES_OWNER":"$REDMINE_FILES_GROUP" "`dirname "$MYSQL_REDMINE_CNF_FILE_PATH"`"
fi
debug "Generating a mysql cnf file to '$MYSQL_REDMINE_CNF_FILE_PATH'"
cat > "$MYSQL_REDMINE_CNF_FILE_PATH" <<ENDCAT
[client]
host        = localhost
user        = "$REDMINE_MYSQL_USERNAME"
password    = "$mysql_redmine_password"
ENDCAT
chown "$REDMINE_FILES_OWNER:$REDMINE_FILES_GROUP" "$MYSQL_REDMINE_CNF_FILE_PATH"

debug "Adding the CNF file path to the environment file"
cat >> "$REDMINE_ENV_FILE_" <<ENDCAT

REDMINE_MYSQL_CNF_FILE="$MYSQL_REDMINE_CNF_FILE_PATH"

ENDCAT

