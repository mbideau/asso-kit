# Redmine Asso Kit

Shell scripts to install [Redmine](http://www.redmine.org/) plus ~25 plugins and [Gitolite](https://github.com/sitaramc/gitolite), all translated 100% to french.

## Installation

	sudo ./install.sh

## Shell scripts

### scripts/setup_system.sh

This is the system setup script.  
Run it as *root* _(required to add user, setup directories and install packages)_.

### scripts/deploy_redmine_source_code.sh

This is the redmine source code deployment script.  
It is automatically ran by the script above, but if you want to run it manually, do it as the redmine user

### scripts/deploy_plugins_and_theme.sh

This is the ~25 plugins +1 theme ([gitmike](https://github.com/makotokw/redmine-theme-gitmike)) installation script.  
Run it as the redmine user.  
_This one is very long to execute because of the compilation of natives extensions_.

### scripts/install_gitolite_and_plugin_git_hosting.sh

This is the installation of [gitolite](https://github.com/sitaramc/gitolite) and the [redmine_git_hosting](http://redmine-git-hosting.io/) plugin that manages git repositories.  
Run it as *root* _(required to add user, setup directories, and install packages)_.

