$LOAD_PATH.unshift '/opt/rh/cfme-gemset/bundler/gems/rest-client-08480eb86aef/lib'
require 'uri'
require 'rest-client'
require 'json'
require 'openssl'
require 'base64'

foreman_host      = $evm.object['foreman_host']
foreman_user      = $evm.object['foreman_user']
foreman_password  = $evm.object.decrypt('foreman_password')

@base_url = "https://#{foreman_host}/katello/api/v2"
@headers  = {
  :content_type  => 'application/json',
  :accept        => 'application/json;version=2',
  :authorization => "Basic #{Base64.strict_encode64("#{foreman_user}:#{foreman_password}")}"
}

def invoke_api(method, cmd, payload=nil)
  JSON.load(RestClient::Request.execute({
    :method     => method,
    :url        => "#{@base_url}/#{cmd}",
    :payload    => payload,
    :headers    => @headers,
    :verify_ssl => OpenSSL::SSL::VERIFY_NONE
  }))
end

organization_name = $evm.object['organization_name']
location_name    = $evm.object['location_name']

result = invoke_api(:get, "organizations/?search=%22#{organization_name}%22")
$evm.log("info", "Organization [#{result['results'].first['id']}]")
organization_id = result['results'].first['id']
    
result = invoke_api(:get, "organizations/#{organization_id}/systems")
vm = $evm.root['vm']
uuid = ""
result['results'].each do |sys|
  next unless sys['name'].match(vm.name)
  $evm.log("info", "Found content host #{sys['name']} with uuid #{sys['uuid']}")
  uuid = sys['uuid']
end
if uuid.blank?
  $evm.log("info", "No Content Host Found")
  exit MIQ_OK
end

$evm.log("info", "Deleting content host with uuid #{uuid}")
results = invoke_api(:delete, "organizations/#{organization_id}/systems/#{uuid}")
$evm.log("info", "Results: #{results}")
