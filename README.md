# summit
Summit Presentation

Joseph Bennett - Consultant

Ian Tewksbury  - Senior Consultant

This repository holds all of the CloudForms code for the "Red Hat CloudForms, Red Hat Satellite 6, & Puppet for automating JBoss EAP 6" presentation.  For questions I can be contacted at jbennett@redhat.com.

The CFME directory is where the actual code exists.  To create the zip file that is used to import the domains simply run the script script/mkip.sh in the base directory.  This will create a file 'automate.zip' that can be used to import into the CFME appliance using the rake command, if automate.zip is in ~ then in change to directory /var/www/miq/vmdb:

BUNDLE_GEMFILE=./Gemfile bin/rake evm:automate:restore BACKUP_ZIP_FILE=~/automate.zip

This will import the domains and replace all other domains.

To Setup the service dialog under Automate->Customization Service Dialogs acordian create a dialog that has the following parameter values:  

service_name-> text input; hostgroup-> dynamic drop down pointing to summit/Integration/Satellite6/SatelliteServer/QueryHostgroups; vm_memory-> text input; number_of_sockets-> text input;subnet -> dynamic drop down point to summit/Integration/Satellite6/SatelliteServer/QuerySubnets; domain-> dynamic drop down pointing to summit/Integration/Satellite6/SatelliteServer/QueryDomains; instance_count -> text input


To Setup the services you need to setup a new catalog item in CloudForms Service Catalogs, under the Catalog items acordian.  You setup a generic catalog type and Choose: summit/Service/Provisioning/StateMachines/ServiceProvision_Template/ProvisionService as the Provisioning Entry point.  The retirement entry point is defined at summit/Service/Retirement/StateMachines/ServiceRetirement/Default


To Set up the "Add VM" and "Remove VM" buttons, after creating the service, you will need to go to the service in the Services->Catalogs Tab, Catalog Items acordian and select the service.  In the configuration menu click add a new button, in the Object Details section you need to set it up as a Request, and the request name as "AddVM" or "RemoveVM".

A not on the template the template name is hardcoded for this simulation.  You could have just as easily tagged the templates.  The template is specified in /summit/Service/Provisioning/StateMachines/Methods/create_provision_request method on the line:  template = $evm.vmdb('miq_template').find_by_name('rhel...'),  Here you could have also use the the 'Blank' template and specified the size of the disk to use as well.


A note on the methods: In later versions of CloudForms this will be fixed, but on the current version, the rest-client gem path had to be specified using the following line:

  $LOAD_PATH.unshift '/opt/rh/cfme-gemset/bundler/gems/rest-client-08480eb86aef/lib'

This may be different on your system, so just verify the name of the location in '/opt/rh/cfme-gemset/bundler/gems/rest-client-###/lib'


In order to integrate Satellite 6 with the code create a new class that is a copy of the class provided.  This class will represent a particular Satellite Server, Organization and Location.

Possible expansion points would be to take the Location parameter out of the class code and make it a variable in the service dialogs.
