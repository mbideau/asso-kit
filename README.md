# Redmine Asso Kit

Shell scripts to install [Redmine](http://www.redmine.org/) plus ~25 plugins and [Gitolite](https://github.com/sitaramc/gitolite), all translated 100% to french.

## Installation

	sudo ./install.sh

## Shell scripts

Dependencies overview

	install.sh
		|__scripts/setup_system.sh
		|
		|__scripts/deploy_redmine_and_theme.sh
		|	|__db/update_default_data.sql
		|	|__conf/nginx/asso-kit.local.conf
		|
		|__scripts/deploy_plugins.sh
		|	|__db/update_default_data_plugins.sql
		|	|__locales/better-french.yml
		|
		|__scripts/install_gitolite_and_plugin_git_hosting.sh
		|	|__db/update_default_data_git_hosting.sql
		|
		|__scripts/deploy_asso_kit_plugin.sh
			|__db/update_default_data_asso_kit.sql

All the shell scripts depend on _lib/shell_fancy.sh_, which it just some basic functions to display text in a fancier fashion.
They also dependends on the redmine configuration file _redmine.conf_, which defines redmine username, and files/directories locations.

A testing script exist in _/bin/test_redmine_with_webrick_webserver.sh_ to run a ruby webserver (webrick) if the nginx doesn't work.

### scripts/setup_system.sh

This is the system setup script.  

### scripts/deploy_redmine_and_theme.sh

This is the redmine source code deployment script.  
It also installs a theme ([gitmike](https://github.com/makotokw/redmine-theme-gitmike)).

### scripts/deploy_plugins.sh

This is the ~25 plugins installation script.  
_This one is very long to execute because of the compilation of natives extensions_.

### scripts/install_gitolite_and_plugin_git_hosting.sh

This is the installation of [gitolite](https://github.com/sitaramc/gitolite) and the [redmine_git_hosting](http://redmine-git-hosting.io/) plugin that manages git repositories.  

### scripts/deploy_asso_kit_plugin.sh

This is the [Asso Kit plugin](https://github.com/mbideau/redmine-asso-kit).

