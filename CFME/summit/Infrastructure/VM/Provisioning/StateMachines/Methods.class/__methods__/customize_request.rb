require 'securerandom'
# Get provisioning object
prov = $evm.root["miq_provision"]

$evm.log("info", "Provisioning ID:<#{prov.id}> Provision Request ID:<#{prov.miq_provision_request.id}> Provision Type: <#{prov.provision_type}>")

# Dump all of root's attributes to the log
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{@method} Root:<$evm.root> Attribute - #{k}: #{v}")}

shortname="#{prov.get_option(:vm_target_name).downcase}"
domainname=".sum.iad.salab.redhat.com"
hostname="#{shortname}#{domainname}"

if hostname.nil? or hostname.blank?
    $evm.log("info", "No Hostname in dialog specified, keeping default auto name")
else
    $evm.log("info", "FQDN from Dialog: #{hostname}")
    prov.set_option(:vm_target_name,shortname)
    prov.set_option(:vm_target_hostname,hostname)
end
