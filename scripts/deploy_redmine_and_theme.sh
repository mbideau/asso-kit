#!/bin/sh
# deploy Redmine source code and populate Mysql database

# halt on first error
set -e

THIS_SCRIPT_DIR="`dirname "$0"`"
SRC_ROOT="`dirname "$THIS_SCRIPT_DIR"|xargs realpath`"
SHELL_FANCY="$SRC_ROOT"/lib/shell_fancy.sh
CONFIGURATION_FILE="$SRC_ROOT"/redmine.conf

# redmine configuration
. "$CONFIGURATION_FILE"

# shell fancy
. "$SHELL_FANCY"

title "Deploy Redmine source code and populate Mysql database"

help()
{
	cat <<ENDCAT
This shell script install Redmine source code and populate Mysql database
ENDCAT
usage
}

usage()
{
	cat <<ENDCAT
Usage:
	`basename "$0"`

ENDCAT
}

# help
if [ "$1" = '-h' -o "$1" = '--help' ]
then
	help
	exit
fi

# check mysql configuration file
if [ ! -f "$REDMINE_MYSQL_CNF_FILE" ]
then
	error "File '$REDMINE_MYSQL_CNF_FILE' doesn't exist"
	exit 1
fi

# check existing installation
if [ -e "$REDMINE_EXTRACTED_DIR" ]
then
	error "Existing redmine installation. Please remove '$REDMINE_EXTRACTED_DIR' manually before proceeding."
	exit 1
fi


info "Deploying redmine $REDMINE_VERSION"

debug "Download and extract redmine files"
wget -q -O - "$REDMINE_DL_URL"|tar -xzf - -C "`dirname "$REDMINE_EXTRACTED_DIR"`"/

debug "Creating Redmine current version symbolic link to Redmine version '$REDMINE_VERSION'"
ln -s "$REDMINE_DIRNAME" "$REDMINE_LIB_DIR"/redmine

redmine_version_var_dir="$REDMINE_VAR_DIR"/"$REDMINE_DIRNAME"
debug "Creating new VAR directory to '$redmine_version_var_dir'"
mkdir "$redmine_version_var_dir"

debug "Changing current directory to '$REDMINE_EXTRACTED_DIR'"
cd "$REDMINE_EXTRACTED_DIR"

debug "Moving existing var/log directories to the REDMINE_VAR_DIR/REDMINE_LOG_DIR and symlinking to them"
rm -f files/delete.me
for d in plugins files tmp
do
	debug "Moving '$d' to redmine VAR directory and symlinked to it"
	mv "$d" "$redmine_version_var_dir"/ && ln -s "$redmine_version_var_dir"/"$d" "$d"
done
debug "Creating '$redmine_version_var_dir/files/attachments' directory"
mkdir "$redmine_version_var_dir"/files/attachments
debug "Moving 'public/plugin_assets' to redmine VAR directory and symlinking to it"
rm -fr public/plugin_assets && mkdir "$redmine_version_var_dir"/plugin_assets && ln -s "$redmine_version_var_dir"/plugin_assets public/
debug "Moving 'public/themes' to redmine VAR directory and symlinking to it"
mv public/themes "$redmine_version_var_dir"/ && ln -s "$redmine_version_var_dir"/themes public/
debug "Removing 'log' directory and creating symlink to redmine LOG dir '$REDMINE_LOG_DIR'"
rm -fr log && ln -s "$REDMINE_LOG_DIR" log


info "Configuring Redmine application"

debug "Getting the mysql redmine user name and password"
mysql_redmine_username=`grep -o '^user *= *.*' "$REDMINE_MYSQL_CNF_FILE"|sed 's/^user *= *"\?\([^"]*\)"\?$/\1/'`
mysql_redmine_password=`grep -o '^password *= *.*' "$REDMINE_MYSQL_CNF_FILE"|sed 's/^password *= *"\?\([^"]*\)"\?$/\1/'`

debug "Creating the redmine database configuration to 'config/database.yml'"
sed \
	-e "s/^\(  username: \)root\$/\1$mysql_redmine_username/g" \
	-e "s/^\(  password: \)"'""'"$/\1"'"'"$mysql_redmine_password"'"'"/g" \
	config/database.yml.example \
	> config/database.yml

debug "Creating the redmine application configuration to 'config/configuration.yml'"
sed \
	-e "s#^  attachments_storage_path:\$#\0 $redmine_version_var_dir/files/attachments#" \
	-e "/^  email_delivery:\$/a delivery_method: :sendmail" \
	config/configuration.yml.example \
|sed \
	-e "s#^delivery_method: :sendmail\$#    \0#" \
	> config/configuration.yml

debug "Changing owner and group to redmine"
chown -R "$REDMINE_FILES_OWNER":"$REDMINE_FILES_GROUP" "$REDMINE_LIB_DIR" "$REDMINE_VAR_DIR"


info "Installing required ruby gems (please be patient ...)"
su -c "bundle install --without development test rmagick --path vendor/bundle" $REDMINE_USERNAME >/dev/null

debug "Checking rails version"
rails_version="`su -c "bundle exec rails --version" $REDMINE_USERNAME|sed 's/^Rails \+//'`"
if ! echo "$rails_version"|grep -q '^4\.2\.[0-9]\+\(\.[0-9]\+\)\?$'
then
	warning "Rails version should be '4.2.x' but is '$rails_version'"
fi

debug "Generating application secret token"
su -c "bundle exec rake generate_secret_token" $REDMINE_USERNAME >/dev/null


info "Populating database (please be patient ... ~ 5 min)"

debug "Creating database schema"
su -c "RAILS_ENV=production bundle exec rake db:migrate" $REDMINE_USERNAME >/dev/null

debug "Populating database with default data (fr)"
su -c "RAILS_ENV=production REDMINE_LANG=fr bundle exec rake redmine:load_default_data" $REDMINE_USERNAME >/dev/null

debug "Creating SQL script by replacing %app_title% and %domain% from the source"
tmp_sql=`mktemp '/tmp/redmine_update_data.sql.tmp.XXXXXXXXXX'`
sed -e "s/%app_title%/$APP_TITLE/g" -e "s/%domain%/$DOMAIN/g" "$REDMINE_DEFAULT_DATA_SQL_REDMINE" > "$tmp_sql"

debug "Updating default data with our custom SQL script"
mysql --defaults-extra-file="$REDMINE_MYSQL_CNF_FILE" "$REDMINE_MYSQL_DATABASE_PRODUCTION" < "$tmp_sql"

debug "Removing temp file '$tmp_sql'"
rm -f "$tmp_sql"


info "Installing theme"

debug "Installing gitmike theme"
su -c "git clone -q https://github.com/makotokw/redmine-theme-gitmike.git public/themes/gitmike" $REDMINE_USERNAME

debug "Installing asso-kit theme"
su -c "git clone -q https://github.com/mbideau/redmine-asso-kit-theme.git public/themes/asso-kit" $REDMINE_USERNAME


info "Creating a test shell script to '$REDMINE_TEST_SCRIPT_PATH'"

debug "Copying the redmine test script"
if [ ! -d "`dirname "$REDMINE_TEST_SCRIPT_PATH"`" ]
then
	mkdir -p "`dirname "$REDMINE_TEST_SCRIPT_PATH"`"
	chown "$REDMINE_FILES_OWNER":"$REDMINE_FILES_GROUP" "`dirname "$REDMINE_TEST_SCRIPT_PATH"`"
fi
cp "$REDMINE_TEST_SCRIPT_SRC" "$REDMINE_TEST_SCRIPT_PATH"
chown "$REDMINE_FILES_OWNER":"$REDMINE_FILES_GROUP" "$REDMINE_TEST_SCRIPT_PATH"
chmod +x "$REDMINE_TEST_SCRIPT_PATH"


info "Deploying web server configuration"

if [ "$DEPLOY_NGINX_PASSENGER" = 'true' ]
then
	#~ if [ -f /etc/nginx/"`basename "$REDMINE_NGINX_CONF"`" ]
	#~ then
	#~ 	cp /etc/nginx/"`basename "$REDMINE_NGINX_CONF"`" /etc/nginx/"`basename "$REDMINE_NGINX_CONF"`".ori
	#~ fi
	#~ cp "$REDMINE_NGINX_CONF" /etc/nginx/
	#~ for d in /etc/nginx/conf.d /etc/nginx/site-available /etc/nginx/site-enabled
	#~ do
	#~ 	if [ ! -d "$d" ]
	#~ 	then
	#~ 		mkdir "$d"
	#~ 	fi
	#~ done
	#~ cp "$REDMINE_NGINX_SERVER_CONF" /etc/nginx/conf.d/
	sed -e "s/%domain%/$DOMAIN/g" "$REDMINE_NGINX_SITE_CONF" > /etc/nginx/sites-available/${DOMAIN}.conf
	ln -s ../sites-available/${DOMAIN}.conf /etc/nginx/sites-enabled/

	if ! grep "$DOMAIN" /etc/hosts
	then
		debug "adding domain '$DOMAIN' to /etc/hosts"
		echo "127.0.0.1	$DOMAIN" >> /etc/hosts
	fi

	info "Restarting webserver (nginx)"
	service nginx restart
else
	warning "Web server deployment disabled. Check DEPLOY_NGINX_PASSENGER in '$CONFIGURATION_FILE'"
fi

