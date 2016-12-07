#!/bin/sh

# halt on first error
set -e

THIS_SCRIPT_DIR="`dirname "$0"`"
SRC_ROOT="$THIS_SCRIPT_DIR"
SHELL_FANCY="$SRC_ROOT"/lib/shell_fancy.sh
CONFIGURATION_FILE="$SRC_ROOT"/redmine.conf

# shell fancy
. "$SHELL_FANCY"

# redmine configuration
. "$CONFIGURATION_FILE"


title "Install the Asso Kit (based on Redmine + plugins)"

help()
{
	cat <<ENDCAT
This shell script install the Asso Kit (Redmine and ~25 plugins, plus Gitolite).

This :  
* install some required packages, including development tools like compilers
* create 2 users : one for Redmine, one for Gitolite
* create Mysql databases for Redmine user
* deploys the Redmine + plugins + theme source codes, and populate Mysql database
* configures everything

ENDCAT
usage
}
usage()
{
	cat <<ENDCAT
Usage:
	`basename "$0"`  MYSQL_ADMIN_PASSWORD_FILE  MYSQL_REDMINE_PASSWORD_FILE  [APP_TITLE  [DOMAIN]]

Arguments:
	MYSQL_ADMIN_PASSWORD_FILE		A simple text file that contains Mysql Admin user password
	MYSQL_REDMINE_PASSWORD_FILE		A simple text file that contains Mysql Redmine user password
	APP_TITLE						The application title (optional, default: Asso Kit)
	DOMAIN							The application web site domain (optional, default: asso-kit.local)

ENDCAT
}


# help
if [ "$#" = '0' -o "$1" = '-h' -o "$1" = '--help' ]
then
	help
	exit
fi

app_title="$3"
domain="$4"

# replacing application title
if [ "$app_title" != '' ]
then
	debug "Replacing application by '$app_title' in the configuration file"
	sed "s/^\(APP_TITLE=\).*$/\1'$app_title'/g" -i "$CONFIGURATION_FILE"
fi
# replacing domain
if [ "$domain" != '' ]
then
	debug "Replacing domain by '$domain' in the configuration file"
	sed "s/^\(DOMAIN=\).*$/\1'$domain'/g" -i "$CONFIGURATION_FILE"
fi


# for each shell script
for s in \
	setup_system.sh \
	deploy_redmine_and_theme.sh \
	deploy_plugins.sh \
	install_gitolite_and_plugin_git_hosting.sh \
	deploy_asso_kit_plugin.sh
do
	script_to_launch="$SCRIPTS_DIR"/"$s"
	debug "Launching user setup script '$script_to_launch' ..."

	# specific case for system setup (executed with arguments)
	if [ "$s" = 'setup_system.sh' ]
	then
		"$script_to_launch" "$1" "$2"

	# other shell scripts
	else

		# exec
		"$script_to_launch" 

		# the test, if not disabled
		if [ "$ENABLE_TESTING" = 'true' ]
		then
			info "Testing the installation"
			
			# without nginx, with webrick
			if [ "$DEPLOY_NGINX_PASSENGER" != 'true' ]
			then
				info "Running the webrick (ruby) web server"
				su -c "$REDMINE_TEST_SCRIPT_PATH production" $REDMINE_USERNAME

			# with nginx
			else
				user_action "
Add the following to your /etc/hosts file of the client machine :
`hostname -I` $redmine_domain
"
				user_action"
Then open your browser to :
http://$redmine_domain/
"
				user_action "Hit <enter> to continue"
			read cont
			fi
		fi
	fi
done


info "Cleanup"

debug "Removing temporary directory"
rm -fr "$temp_dir"

debug "Removing the developments tools"
apt-get purge -qq -y \
	make g++ gcc cpp \
	ruby-dev uuid-dev \
	pkg-config build-essential cmake libgpg-error-dev \
	>/dev/null

success "All done ... enjoy"

