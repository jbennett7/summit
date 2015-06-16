$LOAD_PATH.unshift '/opt/rh/cfme-gemset/bundler/gems/rest-client-08480eb86aef/lib'
require 'uri'
require 'rest-client'
require 'json'
require 'openssl'
require 'base64'

foreman_host      = $evm.object['foreman_host']
foreman_user      = $evm.object['foreman_user']
foreman_password  = $evm.object.decrypt('foreman_password')
organization_name = $evm.object['organization_name']
location_name     = $evm.object['location_name']

prov = $evm.root['miq_provision']

$evm.log("info","Provision Request: #{prov.inspect}")
hostgroup_name = prov.options[:ws_values][:hostgroup]
vm             = prov.vm
$evm.log("info","Hostgroup name: #{hostgroup_name}")
$evm.log("info","VM: #{vm.inspect}")

@base_url = "https://#{foreman_host}/api/v2"
@headers  = {
  :content_type  => 'application/json',
  :accept        => 'application/json;version=2',
  :authorization => "Basic #{Base64.strict_encode64("#{foreman_user}:#{foreman_password}")}"
}

def invoke_foreman_api(method, cmd, payload=nil)
  JSON.load(RestClient::Request.execute({
    :method     => method,
    :url        => "#{@base_url}/#{cmd}",
    :payload    => payload,
    :headers    => @headers,
    :verify_ssl => OpenSSL::SSL::VERIFY_NONE
  }))
end

def query_id (type,field,content)
  uri = URI.escape("#{type}/?search=#{field}=\"#{content}\"")
  $evm.log("info", "Search URI: #{uri}")
  rest_result = invoke_foreman_api(:get,uri)
  $evm.log("info", "Results returned: #{rest_result}")
  return rest_result['results'][0]['id'].to_s
end

hostgroup_id    = query_id("hostgroups","name",hostgroup_name)
location_id     = query_id("locations","name",location_name)
organization_id = query_id("organizations","name",organization_name)

hostinfo = JSON.dump({"host"=> {
  "name"            => vm.name,
  "mac"             => vm.mac_addresses[0],
  "hostgroup_id"    => hostgroup_id,
  "location_id"     => location_id,
  "organization_id" => organization_id,
  "build"           => 'true'
}})
$evm.log("info", "Sending Host Details: #{hostinfo}")

$evm.log("info", "Creating host in Foreman")
result = invoke_foreman_api(:post,"hosts",hostinfo)
$evm.log("info", "Return #{result}")

hostid = result['id'].to_s
$evm.log("info", "Host id: #{hostid}")

$evm.log("info", "Storing Foreman host ID of new VM: #{hostid}")
prov.set_option(:hostid,hostid)

$evm.log("info", "Powering on VM")
vm.start

exit MIQ_OK
