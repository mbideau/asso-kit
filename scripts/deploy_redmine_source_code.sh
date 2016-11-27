#!/bin/sh
# deploy Redmine source code and populate Mysql database

# halt on first error
set -e

SHELL_FANCY="`dirname "$0"`"/shell_fancy.sh
REDMINE_CONFIGURATION_FILE="`dirname "$0"`"/redmine.conf

# shell fancy
. "$SHELL_FANCY"

# redmine configuration
. "$REDMINE_CONFIGURATION_FILE"

# specific configuration
REDMINE_VERSION=3.3.1
REDMINE_DIRNAME=redmine-${REDMINE_VERSION}
REDMINE_DL_URL=http://www.redmine.org/releases/${REDMINE_DIRNAME}.tar.gz
REDMINE_EXTRACTED_DIR="$REDMINE_LIB_DIR"/"$REDMINE_DIRNAME"

title "Deploy Redmine source code and populate Mysql database"

hepl()
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

info "Installing required ruby gems (please be patient ...)"
bundle install --without development test rmagick --path vendor/bundle >/dev/null

debug "Checking rails version"
rails_version="`bundle exec rails --version|sed 's/^Rails \+//'`"
if ! echo "$rails_version"|grep -q '^4\.2\.[0-9]\+\(\.[0-9]\+\)\?$'
then
	warning "Rails version should be '4.2.x' but is '$rails_version'"
fi

debug "Generating application secret token"
bundle exec rake generate_secret_token >/dev/null

info "Populating database"

debug "Creating database schema"
RAILS_ENV=production bundle exec rake db:migrate >/dev/null

debug "Populating database with default data (fr)"
RAILS_ENV=production REDMINE_LANG=fr bundle exec rake redmine:load_default_data >/dev/null

debug "Creating a script to easily run the webrick webserver (use it only for testing purpose)"
cat > run_webrick_webserver.sh <<ENDCAT
#!/bin/sh

set -e

environment="\$1"
if [ "\$environment" = "" ]
then
	environment=production
fi

# be careful : binding to 0.0.0.0 will allow connection from the outside (not only localhost)
bundle exec rails server webrick --environment "\$environment" --binding=0.0.0.0

ENDCAT
chmod +x run_webrick_webserver.sh

info "Testing the installation"

debug "Running the webrick server"
if ! ./run_webrick_webserver.sh production
then
	echo -n >/dev/null # do nothing
fi


