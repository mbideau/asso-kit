#!/bin/sh
# deploy ~25 Redmine plugins source code and populate Mysql database

# halt on first error
set -e

SHELL_FANCY="`dirname "$0"`"/shell_fancy.sh
REDMINE_CONFIGURATION_FILE="`dirname "$0"`"/redmine.conf

ONLY_RUN_BUNDLE_INSTALL_AT_THE_END=true
ONLY_RUN_RAKE_PLUGINS_AT_THE_END=true

# shell fancy
. "$SHELL_FANCY"

# redmine configuration
. "$REDMINE_CONFIGURATION_FILE"

title "Deploy ~25 Redmine plugins source code and populate Mysql database"

hepl()
{
	cat <<ENDCAT
This shell script deploys ~25 Redmine plugins source code and populate Mysql database
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
		bundle install --without development test --path vendor/bundle >/dev/null
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
			bundle exec rake redmine:plugins NAME="$plugin_name" RAILS_ENV="$environment" >/dev/null
		else
			bundle exec rake redmine:plugins RAILS_ENV="$environment" >/dev/null
		fi
	fi
}

install_plugin_from_git()
{
	git_repo_url="$1"
	plugin_name="$2"
	branch_or_tag="$3"

	debug "Installing $plugin_name from git"
	git clone -q "$git_repo_url" plugins/"$plugin_name"
	if [ "$branch_or_tag" != '' ]
	then
		cd plugins/"$plugin_name"
		git checkout -q "$branch_or_tag"
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
	wget -q -O - "$tar_url"|tar -xzf - -C plugins
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
info "CKEditor"
debug "Installing redmine_ckeditor from git"
rails_version="`bundle exec rails --version|sed 's/^Rails \+//'`"
echo "gem \"activesupport\", \"$rails_version\"" >> Gemfile.local
bundle_install
#bundle install --without development test --path vendor/bundle --gemfile Gemfile.local >/dev/null
git clone -q https://github.com/a-ono/redmine_ckeditor.git plugins/redmine_ckeditor
cd plugins/redmine_ckeditor
git checkout -q 1.1.4
cd - >/dev/null
bundle update sprockets-rails >/dev/null
bundle_install
rake_plugins redmine_ckeditor
echo 'defaultLanguage: "fr"' \
| cat plugins/redmine_ckeditor/config/ckeditor.yml.example - \
| sed \
	-e 's/\(removePlugins: \)"[^"]*"$/\1"div,forms"/g' \
	> config/ckeditor.yml
mkdir files/system
ln -s ../files/system public/

# install redmine dashboard (KanBan method)
info "Dashboard"
install_plugin_from_git \
	https://github.com/jgraichen/redmine_dashboard.git \
	redmine_dashboard \
	stable-v2
ln -s redmine_dashboard public/plugin_assets/redmine_dashboard_linked

# install per project text formatting
info "Per project text formatting"
install_plugin_from_git \
	https://github.com/a-ono/redmine_per_project_formatting.git \
	redmine_per_project_formatting

# install issue badge (notification of the number of currently assigned issues to me)
info "Issue badge"
install_plugin_from_git \
	https://github.com/akiko-pusu/redmine_issue_badge.git \
	redmine_issue_badge

# install repetitive task
info "Repetitive tasks"
install_plugin_from_git \
	https://github.com/nutso/redmine-plugin-recurring-tasks.git \
	recurring_tasks

# install scheduling poll
info "Schedulling poll"
install_plugin_from_git \
	https://github.com/cat-in-136/redmine_scheduling_poll.git \
	redmine_scheduling_poll

# install DMSF (document management system)
info "DMSF (Documents)"
install_plugin_from_git \
	https://github.com/danmunn/redmine_dmsf.git \
	redmine_dmsf
mkdir files/dmsf
mkdir files/dmsf_index

# install redmine tab (add custom tab - iframe - per project adn system wide)
info "Tab (extra tab)"
install_plugin_from_git \
	https://github.com/jamtur01/redmine_tab.git \
	redmine_tab

# install lightbox2 (show attachments - image, pdf and flash - into a modal window)
info "Lightbox 2"
install_plugin_from_git \
	https://github.com/paginagmbh/redmine_lightbox2.git \
	redmine_lightbox2

# install checklist (simple checklist into issue)
info "Issue Checklist"
install_plugin_from_git \
	https://github.com/Undev/redmine_issue_checklist.git \
	redmine_issue_checklist

# install redmine ICS export (export calendar as ICal feed)
info "ICS export"
install_plugin_from_git \
	https://github.com/buschmais/redmics.git \
	redmine_ics_export

# install local avatar
info "Local Avatar"
install_plugin_from_git \
	https://github.com/ncoders/redmine_local_avatars.git \
	redmine_local_avatars

# install sidebar hide
info "Sidebar Hide"
install_plugin_from_git \
	https://github.com/bdemirkir/sidebar_hide.git \
	sidebar_hide

# install archive issue categories
info "Archive issue categories"
install_plugin_from_git \
	https://github.com/tofi86/redmine_archive_issue_categories.git \
	redmine_archive_issue_categories

# install banner
info "Banner"
install_plugin_from_git \
	https://github.com/akiko-pusu/redmine_banner.git \
	redmine_banner

# install closed issue
info "Closed Issue"
install_plugin_from_git \
	https://github.com/thorin/redmine_closed_issue.git \
	redmine_closed_issue

# install didyoumean
info "Did you mean"
install_plugin_from_git \
	https://github.com/abahgat/redmine_didyoumean.git \
	redmine_didyoumean

# install drafts
info "Drafts"
install_plugin_from_git \
	https://github.com/jbbarth/redmine_drafts.git \
	redmine_drafts

# install mentions
info "Mentions"
# install_plugin_from_git \
# 	https://github.com/stpl/redmine_mention_plugin.git \
# 	redmine_mention_plugin
debug "Installing redmine_mention_plugin from git"
git clone -q https://github.com/stpl/redmine_mention_plugin.git plugins/redmine_mention_plugin
if ! grep -q ':via' plugins/redmine_mention_plugin/config/routes.rb
then
	sed 's/$/, :via => [:get, :post]/' -i plugins/redmine_mention_plugin/config/routes.rb
fi
bundle_install
rake_plugins redmine_mention_plugin

# install project alias 2
info "Project Alias 2"
install_plugin_from_git \
	https://github.com/paginagmbh/redmine_project_alias_2.git \
	redmine_project_alias_2

# install silencer
info "Silencer"
install_plugin_from_git \
	https://github.com/paginagmbh/redmine_silencer.git \
	redmine_silencer

# install zxcvbn (password checker)
info "ZXCVBN (password checker)"
install_plugin_from_git \
	https://github.com/schmidt/redmine_zxcvbn.git \
	redmine_zxcvbn

# install redmine_language_change
info "Language change"
# install_plugin_from_git \
# 	https://github.com/edavis10/redmine_language_change.git \
# 	z_redmine_language_change
debug "Installing redmine_language_change from git"
git clone -q https://github.com/edavis10/redmine_language_change.git plugins/z_redmine_language_change
sed 's/redmine_language_change/z_\0/' -i plugins/z_redmine_language_change/init.rb
bundle_install
rake_plugins z_redmine_language_change


# @TODO install theme (ecloserie)
#git clone https://github.com/makotokw/redmine-theme-gitmike.git themes/gitmike


if [ "$ONLY_RUN_BUNDLE_INSTALL_AT_THE_END" = 'true' ]
then
	info "Installing gem dependencies (please be patient ...)"
	bundle update rake >/dev/null
	bundle_install --end
fi
if [ "$ONLY_RUN_RAKE_PLUGINS_AT_THE_END" = "true" ]
then
	info "Populating Mysql database (please be patient ...)"
	rake_plugins --end
fi

info "Testing the installation"
debug "Running the webrick server"
if ! ./run_webrick_webserver.sh production
then
	echo -n >/dev/null # do nothing
fi

