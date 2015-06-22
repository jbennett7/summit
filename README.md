# summit
Summit Presentation

Joseph Bennett - Consultant

Ian Tewksbury  - Senior Consultant

This repository holds all of the CloudForms code for the "Red Hat CloudForms, Red Hat Satellite 6, & Puppet for automating JBoss EAP 6" presentation.

The CFME directory is where the actual code exists.  To create the zip file that is used to import the domains simply run the script script/mkip.sh in the base directory.  This will create a file 'automate.zip' that can be used to import into the CFME appliance using the rake command, if automate.zip is in ~ then in change to directory /var/www/miq/vmdb:

BUNDLE_GEMFILE=./Gemfile bin/rake evm:automate:restore BACKUP_ZIP_FILE=~/automate.zip

This will import the domains and replace all other domains.


A note on the methods: In later versions of CloudForms this will be fixed, but on the current version, the rest-client gem path had to be specified using the following line:

  $LOAD_PATH.unshift '/opt/rh/cfme-gemset/bundler/gems/rest-client-08480eb86aef/lib'

This may be different on your system, so just verify the name of the location in '/opt/rh/cfme-gemset/bundler/gems/rest-client-###/lib'


In order to integrate Satellite 6 with the code create a new class that is a copy of the class provided.  This class will represent a particular Satellite Server, Organization and Location.

Possible expansion points would be to take the Location parameter out of the class code and make it a variable in the service dialogs.
