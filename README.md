# summit
Summit Presentation

Joseph Bennett - Consultant

Ian Tewksbury  - Senior Consultant

This repository holds all of the CloudForms code for the "Red Hat 
CloudForms, Red Hat Satellite 6, & Puppet for automating JBoss EAP 6"
presentation.

The CFME directory is where the actual code exists.  To create the zip
file that is used to import the domains simply run the script 
script/mkip.sh in the base directory.  This will create a file 
'automate.zip' that can be used to import into the CFME appliance using
the rake command, if automate.zip is in ~ then in change to directory
/var/www/miq/vmdb:
  bin/rake evm:automate:restore BACKUP_ZIP_FILE=~/automate.zip

This will import the domains and replace all other domains.

A note on the methods: In later versions of CloudForms this will be fixed, but on the current version, the rest-client gem had to use the the line as seen on line one on all of the Satellite 6 integration scripts.
