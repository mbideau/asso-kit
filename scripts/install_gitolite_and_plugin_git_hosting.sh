#!/bin/bash

set -e

SHELL_FANCY="`dirname "$0"`"/../lib/shell_fancy.sh
REDMINE_CONFIGURATION_FILE="`dirname "$0"`"/../redmine.conf
GIT_USER=git
GIT_GROUP=git

# shell fancy
. "$SHELL_FANCY"

# dirs configuration
. "$REDMINE_CONFIGURATION_FILE"

title "Installation of the Redmine plugin 'Git Hosting' and 'Gitolite'"

hepl()
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
apt-get -qq -y install pkg-config build-essential libssh2-1 libssh2-1-dev cmake libgpg-error-dev

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
sudo -u $GIT_USER git clone -q git://github.com/sitaramc/gitolite /home/$GIT_USER/gitolite

debug "Running the gitolite install script"
sudo -u $GIT_USER mkdir /home/$GIT_USER/bin
sudo -u $GIT_USER mkdir -p /home/$GIT_USER/.gitolite/logs
su -c "/home/$GIT_USER/gitolite/install -to /home/$GIT_USER/bin" $GIT_USER

debug "Adding SSH keypairs for $REDMINE_USERNAME"
sudo -u $REDMINE_USERNAME ssh-keygen -t rsa -N '' -f $REDMINE_USER_HOME/.ssh/redmine_gitolite_admin_id_rsa >/dev/null

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
sudo -u $GIT_USER ln -s /var/repo/gitolite /home/$GIT_USER/repositories

debug "Setting up gitolite to accept local hooks"
sudo -u $GIT_USER mkdir /home/$GIT_USER/local
sudo -u $GIT_USER sed -i "s/^\( *GIT_CONFIG_KEYS *=> *\)'' *, *$/\1'.*',/g" /home/$GIT_USER/.gitolite.rc
sudo -u $GIT_USER sed -i 's/^\( *\)# *\(LOCAL_CODE *=> *"$ENV{HOME}\/local" *,\) *$/\1\2/g' /home/$GIT_USER/.gitolite.rc

info "Allowing $REDMINE_USERNAME user to sudo to $GIT_USER"
cat > /etc/sudoers.d/${REDMINE_USERNAME}-to-$GIT_USER <<EOF
Defaults:$REDMINE_USERNAME !requiretty
$REDMINE_USERNAME ALL=($GIT_USER) NOPASSWD:ALL
EOF
chmod 440 /etc/sudoers.d/${REDMINE_USERNAME}-to-$GIT_USER

info "Checking gitolite install (sshing localy)"
check_gitolite_tmp=`mktemp '/tmp/check_gitolite.tmp.XXXXXXXXXX'`
sudo -u $REDMINE_USERNAME ssh -i $REDMINE_USER_HOME/.ssh/redmine_gitolite_admin_id_rsa $GIT_USER@localhost info > "$check_gitolite_tmp"
if ! grep -q "hello redmine_gitolite_admin_id_rsa, this is $GIT_USER@[0-9a-zA-Z_-]\+ running gitolite3 v[0-9a-z.-]\+ on git [0-9.]\+" "$check_gitolite_tmp" || ! grep -q 'R W  *gitolite-admin' "$check_gitolite_tmp" || ! grep -q 'R W  *testing' "$check_gitolite_tmp"
then
	rm -f "$check_gitolite_tmp"
	error "Gitolite seem to not be installed correctly."
	user_action "Run the following command :"
	code "sudo -u $REDMINE_USERNAME ssh -i $REDMINE_USER_HOME/.ssh/redmine_gitolite_admin_id_rsa $GIT_USER@localhost info" "root"
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

info "Installing redmine_git_hosting"

debug "Installing redmine_bootstrap_kit from git"
sudo -u $REDMINE_USERNAME git clone -q https://github.com/jbox-web/redmine_bootstrap_kit.git plugins/redmine_bootstrap_kit
cd plugins/redmine_bootstrap_kit
sudo -u $REDMINE_USERNAME git checkout -q 0.2.4
cd - >/dev/null
sudo -u $REDMINE_USERNAME bundle install --without development test --path vendor/bundle >/dev/null
sudo -u $REDMINE_USERNAME bundle exec rake redmine:plugins NAME="redmine_bootstrap_kit" RAILS_ENV="production" >/dev/null

debug "Installing redmine_git_hosting from git"
sudo -u $REDMINE_USERNAME git clone -q https://github.com/jbox-web/redmine_git_hosting.git plugins/redmine_git_hosting
cd plugins/redmine_git_hosting
sudo -u $REDMINE_USERNAME git checkout -q 1.2.1
cd - >/dev/null
sudo -u $REDMINE_USERNAME bundle install --without development test --path vendor/bundle >/dev/null
sudo -u $REDMINE_USERNAME bundle exec rake redmine:plugins NAME="redmine_git_hosting" RAILS_ENV="production" >/dev/null

debug "Adding the $REDMINE_USERNAME redmine admin ssh key pairs to the plugin directory wiith symlinhks"
sudo -u $REDMINE_USERNAME ln -s $REDMINE_USER_HOME/.ssh/redmine_gitolite_admin_id_rsa* plugins/redmine_git_hosting/ssh_keys/

info "Testing the installation"

cat <<ENDCAT

Check that the Git Hosting plugin is installed correctly by going to :
	Git hosting configuration > Test de la configuration

If everything looks fine, you should deploy git hosting hooks by going to :
	Git hosting configuration > Hook tab > Installer les hooks ! 
Then go back to the tab 'Test de la configuration' after having refreshed the page.

ENDCAT

debug "Running the webrick server"
if ! ./run_webrick_webserver.sh production
then
	echo -n >/dev/null # do nothing
fi

