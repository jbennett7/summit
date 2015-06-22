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

def retry_method(msg, retry_interval = 60)
	$evm.log("info", "Retrying current state: [#{msg}]")
	$evm.root['ae_result'] = 'retry'
	$evm.root['ae_reason'] = msg.to_s
	$evm.root['ae_retry_interval'] = retry_interval
	exit MIQ_OK
end

prov = $evm.root['miq_provision']
unless prov.source.nil?
  unless prov.source.platform == "linux"
    $evm.log("info", "Request is #{prov.source.platform}, not Linux, skipping foreman registration.")
    exit MIQ_OK
  end
end
foreman_host_id  = prov.get_option(:hostid)

rest_result = invoke_foreman_api(:get, "hosts/#{foreman_host_id}/status")
status = rest_result['status']
$evm.log("info", "Status for VM #{prov.vm.name}: #{status}")

case status.downcase
when 'no changes'
  $evm.root['ae_result'] = 'ok'
  $evm.log("info", "Puppet Configuration Complete")
  exit MIQ_OK
when 'error'
  # in many environments the first puppet run will always fail
  # in this case you might want to treat the error as a non critical event instead
  $evm.log("error", "Puppet reported an error")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Puppet reported an error"
  exit MIQ_OK
else
  retry_method("Waiting for Puppet Report")
  $evm.root['ae_result'] = 'ok'
  $evm.log("info", "Puppet Configuration Complete")
  exit MIQ_OK
end
