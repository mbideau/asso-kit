# Asso Kit

A web platform all-in-one for associations and collaborative projects.

Based on [Redmine](http://www.redmine.org/) plus ~25 plugins, 100% translated to french (with proper semantics).

For each project see the availables features :

* *Activity feed* : to know who has done what and when
* *Task management*, with many visualisations: List, Roadmap, Kanban, Calendar, Report
* *Wiki*, with WYSIWYG editor
* *Blog*, with comments
* *Forum*, to debate
* *Documents*, private documents with versioning
* *Downloads*, public files
* *Repository of versioned files*, for documents that changes often, with an automatic synchronisation between members


## Technology

AssoKit is nothing more than a [Redmine](http://www.redmine.org/) custom setup that combine more than ~25 plugins.

Other third party software were added in conjuction to make it even more feature full, like :

* [Gitolite](https://github.com/sitaramc/gitolite)
* [GitAnnex](http://git-annex.branchable.com/)


## Installation

	# create two files, one for the mysql admin password, the other for the redmine mysql user
	touch ~/.config/mysql/admin.pass
	vi ~/.config/mysql/admin.pass # write the password
	touch ~/.config/mysql/redmine.pass
	vi ~/.config/mysql/redmine.pass # write the password

	# run the install script
	sudo ./install.sh ~/.config/mysql/admin.pass ~/.config/mysql/redmine.pass

	# remove the password files
	rm -f ~/.config/mysql/admin.pass ~/.config/mysql/redmine.pass


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
It also installs a theme ([asso-kit](https://github.com/mbideau/redmine-asso-kit-theme)).

### scripts/deploy_plugins.sh

This is the ~25 plugins installation script.  
_This one is very long to execute because of the compilation of natives extensions_.

### scripts/install_gitolite_and_plugin_git_hosting.sh

This is the installation of [gitolite](https://github.com/sitaramc/gitolite) and the [redmine_git_hosting](http://redmine-git-hosting.io/) plugin that manages git repositories.  
It also install [git-annex](http://git-annex.branchable.com/).

### scripts/deploy_asso_kit_plugin.sh

This is the [Asso Kit plugin](https://github.com/mbideau/redmine-asso-kit).


## Use GitAnnex

To use git-annex synchronisation, follow those steps :

1. On your local machine, generate ssh keypairs for your user :  
    ```
	ssh-keygen -t rsa -N '' -C 'AssoKit user key' -f ~/.ssh/id_rsa_assokit
    ```

2. On AssoKit website, add the keys to your user by going to `MyAccount > SSH Keys`, and copy the content of the public key :  
    ```
	cat ~/.ssh/id_rsa_assokit.pub
    ```

3. On AssoKit website, create a git-annex repository by going to :  
   `<project> > Configuration > Repositories > New repository`  
   
   Then, select 'Initialize with GitAnnex'  
   
   *You must have a user role with commit permission on this project*  

4. On your local machine, install git-annex :  
    ```
	sudo apt-get -qq -y install --no-install-recommends git-annex lsof
    ```

5. On your local machine, clone the git-annex repository :  
    ```
	git clone -q ssh://git@<domain>/<project>/<repository_name>.git /tmp/test-git-annex-repo.tmp
    ```

6. On your local machine, start git-annex webapp, by clicking on its icon, or with :  
    ```
	git-annex webapp
    ```

7. On your local machine, add the cloned git-annex repository by entering its path to the invite 'Make Repository'.  
   In this example it will be : _/tmp/test-git-annex-repo.tmp_   

You're done.

