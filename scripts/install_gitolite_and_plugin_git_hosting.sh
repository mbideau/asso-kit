#!/bin/bash

set -e

THIS_SCRIPT_DIR="`dirname "$0"`"
SRC_ROOT="`dirname "$THIS_SCRIPT_DIR"|xargs realpath`"

SHELL_FANCY="$SRC_ROOT"/lib/shell_fancy.sh
CONFIGURATION_FILE="$SRC_ROOT"/redmine.conf

REDMINE_UPDATE_DEFAULT_DATA_SQL="$SRC_ROOT"/db/update_default_data_git_hosting.sql

GIT_USER=git
GIT_GROUP=git

# redmine configuration
. "$CONFIGURATION_FILE"

REDMINE_MYSQL_CNF_FILE=$REDMINE_USER_HOME/.config/mysql/redmine.cnf

REDMINE_TEST_SCRIPT_PATH="$REDMINE_USER_HOME"/bin/test_redmine_with_webrick_webserver.sh

# shell fancy
. "$SHELL_FANCY"

title "Installation of the Redmine plugin 'Git Hosting' and 'Gitolite'"

help()
{
	cat <<ENDCAT
This shell script installs the Redmine plugin 'Git Hosting' and 'Gitolite'
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


info "Installing packages dependencies"
apt-get -qq -y install --no-install-recommends pkg-config build-essential libssh2-1 libssh2-1-dev cmake libgpg-error-dev >/dev/null


info "Adding git/gitolite dedicated user named '$GIT_USER'"
adduser --system --shell /bin/bash --gecos 'Git Administrator' --group --disabled-password --home /home/$GIT_USER $GIT_USER >/dev/null
debug "Creating a .profile for $GIT_USER, that add /home/$GIT_USER/bin to the PATH"
cat > /home/$GIT_USER/.profile <<EOF
#!/bin/sh

# set PATH so it includes user private bin if it exists
if [ -d "\$HOME/bin" ] ; then
	PATH="\$PATH:\$HOME/bin"
fi
EOF
chown $GIT_USER:$GIT_GROUP /home/$GIT_USER/.profile


info "Installing gitolite"

debug "Getting gitolite source code from github"
su -c "git clone -q git://github.com/sitaramc/gitolite /home/$GIT_USER/gitolite" $GIT_USER 

debug "Running the gitolite install script"
su -c "mkdir /home/$GIT_USER/bin" $GIT_USER
su -c "mkdir -p /home/$GIT_USER/.gitolite/logs" $GIT_USER
su -c "/home/$GIT_USER/gitolite/install -to /home/$GIT_USER/bin" $GIT_USER

debug "Adding SSH keypairs for $REDMINE_USERNAME"
su -c "ssh-keygen -t rsa -N '' -f $REDMINE_USER_HOME/.ssh/redmine_gitolite_admin_id_rsa" $REDMINE_USERNAME >/dev/null

debug "Copying SSH public key to git user home"
cp $REDMINE_USER_HOME/.ssh/redmine_gitolite_admin_id_rsa.pub /home/$GIT_USER/
chown $GIT_USER:$GIT_GROUP /home/$GIT_USER/redmine_gitolite_admin_id_rsa.pub

debug "Running the gitolite setup script with the SSH public key"
su -c "/home/$GIT_USER/bin/gitolite setup -pk /home/$GIT_USER/redmine_gitolite_admin_id_rsa.pub" $GIT_USER

debug "Moving the repositories to /var"
if [ ! -d /var/repo ]
then
	mkdir /var/repo
fi
mv /home/$GIT_USER/repositories /var/repo/gitolite
su -c "ln -s /var/repo/gitolite /home/$GIT_USER/repositories" $GIT_USER

debug "Setting up gitolite to accept local hooks"
su -c "mkdir /home/$GIT_USER/local" $GIT_USER
su -c "sed -i \"s/^\( *GIT_CONFIG_KEYS *=> *\)'' *, *$/\1'.*',/g\" /home/$GIT_USER/.gitolite.rc" $GIT_USER
su -c "sed -i 's/^\( *\)# *\(LOCAL_CODE *=> *\"\$ENV{HOME}\/local\" *,\) *$/\1\2/g' /home/$GIT_USER/.gitolite.rc" $GIT_USER


info "Allowing $REDMINE_USERNAME user to sudo to $GIT_USER"
cat > /etc/sudoers.d/${REDMINE_USERNAME}-to-$GIT_USER <<EOF
Defaults:$REDMINE_USERNAME !requiretty
$REDMINE_USERNAME ALL=($GIT_USER) NOPASSWD:ALL
EOF
chmod 440 /etc/sudoers.d/${REDMINE_USERNAME}-to-$GIT_USER


info "Checking gitolite install (sshing localy)"
check_gitolite_tmp=`mktemp '/tmp/check_gitolite.tmp.XXXXXXXXXX'`
su -c "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $REDMINE_USER_HOME/.ssh/redmine_gitolite_admin_id_rsa $GIT_USER@localhost info" $REDMINE_USERNAME > "$check_gitolite_tmp"
if ! grep -q "^hello redmine_gitolite_admin_id_rsa, this is ${GIT_USER}@[0-9a-zA-Z_-]\+ running gitolite3 v[0-9a-z.-]\+ on git [0-9.]\+" "$check_gitolite_tmp" || ! grep -q '^ R W	gitolite-admin' "$check_gitolite_tmp" || ! grep -q '^ R W	testing' "$check_gitolite_tmp"
then
	rm -f "$check_gitolite_tmp"
	error "Gitolite seem to not be installed correctly."
	user_action "Run the following command :"
	code "su -c \"ssh -i $REDMINE_USER_HOME/.ssh/redmine_gitolite_admin_id_rsa $GIT_USER@localhost info\" $REDMINE_USERNAME" "root"
	user_action "And check its result compared to the following output :"
cat <<ENDCAT
--- debug example ---
hello redmine_gitolite_admin_id_rsa, this is git@wvs3 running gitolite3 v3.6.6-1-g5c2fe87 on git 2.1.4

 R W	gitolite-admin
 R W	testing
--- end example ---
ENDCAT
	echo "If it doesn't match at all, gitolite installation has failed and you should stop here"
	echo "Else, you can continue this installation"
	user_action "Hit <enter> to continue"
	read cont
fi
rm -f "$check_gitolite_tmp"

redmine_current_lib_dir="$REDMINE_LIB_DIR"/redmine
cd "$redmine_current_lib_dir"


info "Installing redmine_git_hosting (please be patient ... ~ 5 min)"

debug "Installing redmine_bootstrap_kit from git"
su -c "git clone -q https://github.com/jbox-web/redmine_bootstrap_kit.git plugins/redmine_bootstrap_kit" $REDMINE_USERNAME
cd plugins/redmine_bootstrap_kit
su -c "git checkout -q 0.2.4" $REDMINE_USERNAME
cd - >/dev/null
su -c "bundle install --without development test --path vendor/bundle" $REDMINE_USERNAME >/dev/null
su -c "bundle exec rake redmine:plugins NAME=redmine_bootstrap_kit RAILS_ENV=production" $REDMINE_USERNAME >/dev/null

debug "Installing redmine_git_hosting from git"
su -c "git clone -q https://github.com/jbox-web/redmine_git_hosting.git plugins/redmine_git_hosting" $REDMINE_USERNAME
cd plugins/redmine_git_hosting
su -c "git checkout -q 1.2.1" $REDMINE_USERNAME
cd - >/dev/null
su -c "bundle install --without development test --path vendor/bundle" $REDMINE_USERNAME >/dev/null
su -c "bundle exec rake redmine:plugins NAME=redmine_git_hosting RAILS_ENV=production" $REDMINE_USERNAME >/dev/null

debug "Adding the $REDMINE_USERNAME redmine admin ssh key pairs to the plugin directory wiith symlinhks"
su -c "ln -s $REDMINE_USER_HOME/.ssh/redmine_gitolite_admin_id_rsa* plugins/redmine_git_hosting/ssh_keys/" $REDMINE_USERNAME


info "Updating default data"
debug "Updating default data with our custom SQL script"
mysql --defaults-extra-file="$REDMINE_MYSQL_CNF_FILE" "$REDMINE_MYSQL_DATABASE_PRODUCTION" < "$REDMINE_UPDATE_DEFAULT_DATA_SQL"


info "Installing Gitolite hooks"
su -c "RAILS_ENV=production bundle exec rake redmine_git_hosting:install_gitolite_hooks" $REDMINE_USERNAME >/dev/null


if [ "$DEPLOY_NGINX_PASSENGER" = 'true' ]
then
	info "Restarting webserver (nginx)"
	service nginx restart
fi

