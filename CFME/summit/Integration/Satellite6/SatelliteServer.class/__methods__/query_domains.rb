$LOAD_PATH.unshift '/opt/rh/cfme-gemset/bundler/gems/rest-client-08480eb86aef/lib'
require 'set'
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

rest_result = invoke_foreman_api(:get, "domains")
$evm.log("info", "Rest result: #{rest_result}")

domains = Set.new
rest_result['results'].each do |result|
  domains << result['name']
end

list_values = {
  'sort_by'    => :none,
  'data_type'  => :string,
  'required'   => false,
  'values'     => [[nil, nil]] + domains.collect { |x| x.reverse }.sort
}
 
$evm.log('info', "Hostgroups drop-down: [#{list_values}]")
list_values.each { |k,v| $evm.object[k] = v }

exit MIQ_OK
