$LOAD_PATH.unshift '/opt/rh/cfme-gemset/bundler/gems/rest-client-08480eb86aef/lib'
require 'uri'
require 'rest-client'
require 'json'
require 'openssl'
require 'base64'

foreman_host      = $evm.object['foreman_host']
foreman_user      = $evm.object['foreman_user']
foreman_password  = $evm.object.decrypt('foreman_password')

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

vm    = $evm.root['vm']
vmname = vm.name
$evm.log("info", "Deleting VM #{vm.name} with Hostname #{vmname} from Foreman.")

if vm.platform != "linux" then
  $evm.log("info","This is not a Linux VM, skipping deletion of foreman records")
  exit MIQ_OK
end

rest_result = invoke_foreman_api(:delete, "hosts/#{vmname}")
$evm.log("info", "Rest result: #{rest_result}")

exit MIQ_OK
