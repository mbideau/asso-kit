#!/bin/sh
# deploy ~25 Redmine plugins and populate Mysql database

# halt on first error
set -e

THIS_SCRIPT_DIR="`dirname "$0"`"
SRC_ROOT="`dirname "$THIS_SCRIPT_DIR"|xargs realpath`"
SHELL_FANCY="$SRC_ROOT"/lib/shell_fancy.sh
CONFIGURATION_FILE="$SRC_ROOT"/redmine.conf

ONLY_RUN_BUNDLE_INSTALL_AT_THE_END=true
ONLY_RUN_RAKE_PLUGINS_AT_THE_END=true

# redmine configuration
. "$CONFIGURATION_FILE"

# shell fancy
. "$SHELL_FANCY"

title "Deploy ~25 Redmine plugins and populate Mysql database"

help()
{
	cat <<ENDCAT
This shell script deploys ~25 Redmine plugins and populate Mysql database
ENDCAT
usage
}

usage()
{
	cat <<ENDCAT
Usage:
	`basename "$0"`  ENVIRONMENT

Arguments:
	ENVIRONMENT	The environment to deploy to (defautl: production)
			Can be: production, test, development

ENDCAT
}

# help
if [ "$1" = '-h' -o "$1" = '--help' ]
then
	help
	exit
fi

bundle_install()
{
	end="`echo "$1"|grep -q '^--end$' && echo 'true' || echo 'false'`"
	if [ "$ONLY_RUN_BUNDLE_INSTALL_AT_THE_END" != 'true' -o "$end" = 'true' ]
	then
		su -c "bundle install --without development test --path vendor/bundle" $REDMINE_USERNAME >/dev/null
	fi
}

rake_plugins()
{
	plugin_name="$1"
	end="`echo "$2"|grep -q '^--end$' && echo 'true' || echo 'false'`"
	if [ $# -eq 1 ]
	then
		end="`echo "$1"|grep -q '^--end$' && echo 'true' || echo 'false'`"
		if [ "$end" = "true" ]
		then
			plugin_name=
		fi
	fi
	if [ "$ONLY_RUN_RAKE_PLUGINS_AT_THE_END" != "true" -o "$end" = 'true' ]
	then
		if [ "$plugin_name" != '' ]
		then
			su -c "bundle exec rake redmine:plugins NAME=$plugin_name RAILS_ENV=$environment" $REDMINE_USERNAME >/dev/null
		else
			su -c "bundle exec rake redmine:plugins RAILS_ENV=$environment" $REDMINE_USERNAME >/dev/null
		fi
	fi
}

install_plugin_from_git()
{
	git_repo_url="$1"
	plugin_name="$2"
	branch_or_tag="$3"

	debug "Installing $plugin_name from git"
	su -c "git clone -q \"$git_repo_url\" plugins/$plugin_name" $REDMINE_USERNAME
	if [ "$branch_or_tag" != '' ]
	then
		cd plugins/"$plugin_name"
		su -c "git checkout -q \"$branch_or_tag\"" $REDMINE_USERNAME
		cd - >/dev/null
	fi
	bundle_install
	rake_plugins "$plugin_name"
}

install_plugin_from_tar()
{
	tar_url="$1"
	plugin_name="$2"

	debug "Installing $plugin_name from wget+tar"
	su -c "wget -q -O - \"$tar_url\"|tar -xzf - -C plugins" $REDMINE_USERNAME
	bundle_install
	rake_plugins "$plugin_name"
}

# arguments
environment="$1"
if [ "$environment" = "" ]
then
	environment="production"
fi

debug "Moving the current dir to the redmine current LIB dir"
redmine_current_lib_dir="$REDMINE_LIB_DIR"/redmine
cd "$redmine_current_lib_dir"

# install CKEditor (editor for text formatted sections like issue and wiki)
info " - plugin CKEditor"
debug "Installing redmine_ckeditor from git"
rails_version="`su -c "bundle exec rails --version" $REDMINE_USERNAME|sed 's/^Rails \+//'`"
echo "gem \"activesupport\", \"$rails_version\"" >> Gemfile.local
bundle_install
#bundle install --without development test --path vendor/bundle --gemfile Gemfile.local >/dev/null
su -c "git clone -q https://github.com/a-ono/redmine_ckeditor.git plugins/redmine_ckeditor" $REDMINE_USERNAME
cd plugins/redmine_ckeditor
su -c "git checkout -q 1.1.4" $REDMINE_USERNAME
cd - >/dev/null
su -c "bundle update sprockets-rails" $REDMINE_USERNAME >/dev/null
bundle_install
rake_plugins redmine_ckeditor
echo 'defaultLanguage: "fr"' \
| cat plugins/redmine_ckeditor/config/ckeditor.yml.example - \
| sed \
	-e 's/\(removePlugins: \)"[^"]*"$/\1"div,forms"/g' \
	> config/ckeditor.yml
chown "$REDMINE_FILES_OWNER":"$REDMINE_FILES_GROUP" config/ckeditor.yml
su -c "mkdir files/system" $REDMINE_USERNAME
su -c "ln -s ../files/system public/" $REDMINE_USERNAME

# install redmine dashboard (KanBan method)
info " - plugin Dashboard"
install_plugin_from_git \
	https://github.com/jgraichen/redmine_dashboard.git \
	redmine_dashboard \
	stable-v2
su -c "ln -s redmine_dashboard public/plugin_assets/redmine_dashboard_linked" $REDMINE_USERNAME

# install per project text formatting
info " - plugin Per project text formatting"
install_plugin_from_git \
	https://github.com/a-ono/redmine_per_project_formatting.git \
	redmine_per_project_formatting

# install repetitive task
info " - plugin Repetitive tasks"
install_plugin_from_git \
	https://github.com/nutso/redmine-plugin-recurring-tasks.git \
	recurring_tasks

# install scheduling poll
info " - plugin Schedulling poll"
install_plugin_from_git \
	https://github.com/cat-in-136/redmine_scheduling_poll.git \
	redmine_scheduling_poll

# install DMSF (document management system)
info " - plugin DMSF (Documents)"
install_plugin_from_git \
	https://github.com/danmunn/redmine_dmsf.git \
	redmine_dmsf
su -c "mkdir files/dmsf" $REDMINE_USERNAME
su -c "mkdir files/dmsf_index" $REDMINE_USERNAME

# install redmine tab (add custom tab - iframe - per project adn system wide)
info " - plugin Tab (extra tab)"
install_plugin_from_git \
	https://github.com/jamtur01/redmine_tab.git \
	redmine_tab

# install lightbox2 (show attachments - image, pdf and flash - into a modal window)
info " - plugin Lightbox 2"
install_plugin_from_git \
	https://github.com/paginagmbh/redmine_lightbox2.git \
	redmine_lightbox2

# install checklist (simple checklist into issue)
info " - plugin Issue Checklist"
install_plugin_from_git \
	https://github.com/Undev/redmine_issue_checklist.git \
	redmine_issue_checklist

# install redmine ICS export (export calendar as ICal feed)
info " - plugin ICS export"
install_plugin_from_git \
	https://github.com/buschmais/redmics.git \
	redmine_ics_export

# install local avatar
info " - plugin Local Avatar"
install_plugin_from_git \
	https://github.com/ncoders/redmine_local_avatars.git \
	redmine_local_avatars

# install sidebar hide
info " - plugin Sidebar Hide"
install_plugin_from_git \
	https://github.com/bdemirkir/sidebar_hide.git \
	sidebar_hide

# install archive issue categories
info " - plugin Archive issue categories"
install_plugin_from_git \
	https://github.com/tofi86/redmine_archive_issue_categories.git \
	redmine_archive_issue_categories

# install banner
info " - plugin Banner"
install_plugin_from_git \
	https://github.com/akiko-pusu/redmine_banner.git \
	redmine_banner

# install closed issue
info " - plugin Closed Issue"
install_plugin_from_git \
	https://github.com/thorin/redmine_closed_issue.git \
	redmine_closed_issue

# install didyoumean
info " - plugin Did you mean"
install_plugin_from_git \
	https://github.com/abahgat/redmine_didyoumean.git \
	redmine_didyoumean

# install drafts
info " - plugin Drafts"
install_plugin_from_git \
	https://github.com/jbbarth/redmine_drafts.git \
	redmine_drafts

# install zquery
info " - plugin zQuery"
install_plugin_from_git \
	https://github.com/mbideau/redmine_zquery.git \
	_query

# install mentions
info " - plugin Mentions"
# install_plugin_from_git \
# 	https://github.com/stpl/redmine_mention_plugin.git \
# 	redmine_mention_plugin
debug "Installing redmine_mention_plugin from git"
su -c "git clone -q https://github.com/stpl/redmine_mention_plugin.git plugins/redmine_mention_plugin" $REDMINE_USERNAME
if ! grep -q ':via' plugins/redmine_mention_plugin/config/routes.rb
then
	sed 's/$/, :via => [:get, :post]/' -i plugins/redmine_mention_plugin/config/routes.rb
fi
bundle_install
rake_plugins redmine_mention_plugin

# install project alias 2
info " - plugin Project Alias 2"
install_plugin_from_git \
	https://github.com/paginagmbh/redmine_project_alias_2.git \
	redmine_project_alias_2

# install silencer
info " - plugin Silencer"
install_plugin_from_git \
	https://github.com/paginagmbh/redmine_silencer.git \
	redmine_silencer

# install zxcvbn (password checker)
info " - plugin ZXCVBN (password checker)"
install_plugin_from_git \
	https://github.com/schmidt/redmine_zxcvbn.git \
	redmine_zxcvbn

# install redmine_language_change
info " - plugin Language change"
# install_plugin_from_git \
# 	https://github.com/edavis10/redmine_language_change.git \
# 	z_redmine_language_change
debug "Installing redmine_language_change from git"
su -c "git clone -q https://github.com/edavis10/redmine_language_change.git plugins/z_redmine_language_change" $REDMINE_USERNAME
sed 's/redmine_language_change/z_\0/' -i plugins/z_redmine_language_change/init.rb
bundle_install
rake_plugins z_redmine_language_change
debug "Copying better french locale"
cp "$LOCALES_BETTER_FRENCH" plugins/z_redmine_language_change/config/locales/fr.yml
chown "$REDMINE_FILES_OWNER":"$REDMINE_FILES_GROUP" plugins/z_redmine_language_change/config/locales/fr.yml

#~ # install unread_issues
#~ info " - plugin Unread Issues"
#~ debug "Installing unread_issues from zip file"
#~ unzip -q -d plugins "$UNREAD_ISSUES_ZIP"
#~ chown -R "$REDMINE_FILES_OWNER":"$REDMINE_FILES_GROUP" plugins/unread_issues
#~ bundle_install
#~ rake_plugins unread_issues

if [ "$ONLY_RUN_BUNDLE_INSTALL_AT_THE_END" = 'true' ]
then
	info "Installing gem dependencies (please be patient ... ~ 15 min)"
	su -c "bundle update rake" $REDMINE_USERNAME >/dev/null
	bundle_install --end
fi
if [ "$ONLY_RUN_RAKE_PLUGINS_AT_THE_END" = "true" ]
then
	info "Populating Mysql database (please be patient ... ~ 3 min)"
	rake_plugins --end
fi

info "Updating default data"
debug "Updating default data with our custom SQL script"
mysql --defaults-extra-file="$REDMINE_MYSQL_CNF_FILE" "$REDMINE_MYSQL_DATABASE_PRODUCTION" < "$REDMINE_DEFAULT_DATA_SQL_PLUGINS"


if [ "$DEPLOY_NGINX_PASSENGER" = 'true' ]
then
	info "Restarting webserver (nginx)"
	service nginx restart
fi

