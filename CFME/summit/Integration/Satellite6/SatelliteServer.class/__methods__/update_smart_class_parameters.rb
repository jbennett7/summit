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

def invoke_katello_api(method, cmd, payload=nil)
  JSON.load(RestClient::Request.execute({
    :method     => method,
    :url        => "#{@base_url}/#{cmd}",
    :payload    => payload,
    :headers    => @headers,
    :verify_ssl => OpenSSL::SSL::VERIFY_NONE
  }))
end

def escape_uri(value)
  URI.escape(value, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
end

def invoke_foreman_api(method, cmd, payload=nil)
  JSON.load(RestClient::Request.execute({
    :method     => method,
    :url        => "#{@base_url}/#{cmd}",
    :payload    => payload,
    :headers    => @headers,
    :verify_ssl => OpenSSL::SSL::VERIFY_NONE
  }))
end
def get_foreman_smart_class_params(foreman_smart_class_parameters)
  # Support supplying key/value pairs via attributes
  $evm.current.attributes.each do |k,v|
    next unless match = /^value_(.+)\.(.+)$/.match(k)
    next unless smart_match = $evm.object["match_#{match[1]}.#{match[2]}"]
    foreman_smart_class_parameters << {
      'puppetclass' => match[1],
      'parameter'   => match[2],
      'match'       => smart_match,
      'value'       => v }
  end
end

def create_foreman_smart_class_overrides(foreman_environment_id, foreman_smart_class_parameters)
  # Create specified override values
  foreman_smart_class_parameters.each do |c|
    $evm.log('info', "Collecting current Smart Class Parameter: [#{c}]")
    child_object = invoke_foreman_api(
      :get, 
      "environments/#{foreman_environment_id}/smart_class_parameters",
      :search => "puppetclass=\"#{c['puppetclass']}\" and key=\"#{c['parameter']}\"")
    smart_class_parameters = (child_object['foreman_result'] || [])

    # Should have found a single match
    error("Unable to locate Smart Class Parameter: [#{c['puppetclass']}.#{c['parameter']}]") if smart_class_parameters.blank?
    error("Detected multiple Smart Class Parameters, expecting only one: [#{smart_class_parameters}]") if smart_class_parameters.size > 1

    smart_class_parameter = smart_class_parameters[0]
    override_value = {'match' => c['match'], 'value' => c['value'] }

    delete_ids = Set.new
    duplicate_override = smart_class_parameter['override_values'].find { |v| v['match'] == override_value['match'] }
    if duplicate_override
      if duplicate_override['value'] != override_value['value']
        delete_ids << duplicate_override['id'] 
      else
        $evm.log('info', "Skipping existing smart class parameter override: [#{override_value}]")
        next
      end
    end

    # Delete all specified override values
    delete_ids.each do |id|
      $evm.log('info', "Deleting Smart Class Parameter override: [override: #{id}]")
      invoke_foreman_api(:delete, "smart_class_parameters/#{smart_class_parameter['id']}/override_values/#{id}")
    end

    # Apply specified override values
    $evm.log('info', "Creating Smart Class Parameter override: [#{override_value}]")
    invoke_foreman_api(:post, "smart_class_parameters/#{smart_class_parameter['id']}/override_values", :value => override_value)
  end
end

def delete_foreman_smart_class_parameter_overrides(delete_overrides)
  delete_overrides.each do |delete_override|
    $evm.log('info', "Deleting Smart Class Parameter override: [#{delete_override}]")
    invoke_foreman_api(:delete, "smart_class_parameters/#{delete_override['smart_class_parameter_id']}/override_values/#{delete_override['override_value_id']}")
  end
end

begin
  dump_root()
  dump_current()
  
  foreman_environment_id = $evm.current['foreman_environment_id'] || $evm.root['foreman_environment_id']
  error("Unable to determine Foreman Environment ID") if foreman_environment_id.blank?

  delete_overrides = ($evm.parent && $evm.parent['delete_foreman_smart_class_parameter_overrides']) || []
  delete_foreman_smart_class_parameter_overrides(delete_overrides)
  
  foreman_smart_class_parameters = ($evm.parent && $evm.parent['foreman_smart_class_parameters']) || []
  get_foreman_smart_class_params(foreman_smart_class_parameters)

  create_foreman_smart_class_overrides(foreman_environment_id, foreman_smart_class_parameters)
  $evm.current['result'] = 'ok'
  $evm.current['reason'] = ''
rescue => err
  error(err)
end
# Parses dialog options looking for puppet parameters to pass to Satellite
#
# EX: dialog_puppet_string__jboss_eap__params__artifacts
#     type: string, class, jboss_eap::params, param: artifacts
#
def setup_smart_class_overrides(dialog_options)
  smart_class_parameters = []
  dialog_options.each do |dialog_key, dialog_value|

    # determine if a puppet dialog paramater
    puppet_match = dialog_key.match(/^dialog_puppet_([^__]*)__(.*)/)
    next unless puppet_match
    
    # split the parameter into the variable type and then the class and paramter name
    puppet_type = puppet_match[1]
    puppet_class_and_param = puppet_match[2].gsub(/__/,'::')
    
    # split the puppet class from the puppet param
    puppet_param_start_index = puppet_class_and_param.rindex('::')
    puppet_class = puppet_class_and_param[0..(puppet_param_start_index-1)]
    puppet_param = puppet_class_and_param[(puppet_param_start_index+2)..puppet_class_and_param.length]
    
    # set the value based on the value type
    case puppet_type
      when 'string'
        value = dialog_value
      when 'boolean'
        value = dialog_value.match(/true|T|t/i) ? true : false)
      when 'array'
        value = dialog_value.gsub(/["']/,'').split(/[\n, ]/).reject { |s| s.empty? }
      when 'yaml'
        value = YAML.load(dialog_value).to_yaml
      else
        # TODO: throw error
    end
    
    # create smart param override entry
    smart_class_paramters << { 
      'puppetclass' => puppet_class,
      'parameter'   => puppet_param,
      'match'       => "service_name=#{dialog_options['dialog_service_name']},hostgroup=#{dialog_options['dialog_hostgroup']}",
      'value'       => value }
  end

  $evm.log("info","Storing Smart Class Overrides #{smart_class_parameters}")
  return smart_class_parameters
end

  require 'uri'

FOREMAN_BASE_URI                = "/Integration/Foreman"
FOREMAN_INVOKE_API_URI          = "#{FOREMAN_BASE_URI}/Actions/InvokeForemanApi"
FOREMAN_UPDATE_SMART_PARAMS_URI = "#{FOREMAN_BASE_URI}/Actions/UpdateSmartClassParameters"

def dump_root()
  $evm.log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
  $evm.root.attributes.sort.each { |k, v| $evm.log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
  $evm.log(:info, "Root:<$evm.root> End $evm.root.attributes")
  $evm.log(:info, "")
end

def error(msg)
  $evm.log(:error, msg)
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg.to_s
  exit MIQ_OK
end

def retry_method(msg)
  $evm.log(:warn, "Retrying current state: [#{msg}]")
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_reason'] = msg.to_s
  exit MIQ_OK
end

def escape_uri(value)
  URI.escape(value, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
end

def instantiate(uri)
  $evm.log(:info, "Instantiating: [#{uri}]")
  
  instance = $evm.instantiate(uri)
  error("Failed to locate automation instance") unless instance
  
  case (instance['result'] || instance['ae_result'])
  when 'error'
    error(instance['reason'] || instance['ae_reason'])
  when 'retry'
    retry_method(instance['reason'] || instance['ae_reason'])
  end
  
  instance
end

def update_foreman_smart_class_parameters(
    task, infrastructure_environment, foreman_environment_id, 
    foreman_smart_class_parameters, delete_foreman_smart_class_parameter_overrides)

  # Need to pass the hash through the stack
  $evm.current['foreman_smart_class_parameters'] = foreman_smart_class_parameters
  $evm.current['delete_foreman_smart_class_parameter_overrides'] = delete_foreman_smart_class_parameter_overrides
  
  instantiate("#{FOREMAN_UPDATE_SMART_PARAMS_URI}?" \
    "infrastructure_environment=#{infrastructure_environment}&" \
    "foreman_environment_id=#{foreman_environment_id}&" \
    "replace=true")
end

def get_foreman_hosts(infrastructure_environment, foreman_host_search)
  instantiate("#{FOREMAN_INVOKE_API_URI}?" \
    "infrastructure_environment=#{infrastructure_environment}&" \
    "http_method=get&" \
    "item=hosts&" \
    "search=#{escape_uri(foreman_host_search)}")['foreman_result']
end

def get_foreman_host_smart_class_parameters(infrastructure_environment, foreman_host_id)
  instantiate("#{FOREMAN_INVOKE_API_URI}?" \
    "infrastructure_environment=#{infrastructure_environment}&" \
    "http_method=get&" \
    "item=hosts/#{foreman_host_id}/smart_class_parameters")['foreman_result'] 
end

def collect_obsolete_smart_class_parameter_overrides(
    infrastructure_environment, foreman_environment_id, 
    foreman_host_search, foreman_smart_class_parameters)

  # Collect all Puppet overrides for all hosts matching our application
  foreman_hosts = get_foreman_hosts(infrastructure_environment, foreman_host_search)
  foreman_host_smart_class_parameters = foreman_hosts.collect do |foreman_host|
    get_foreman_host_smart_class_parameters(infrastructure_environment, foreman_host['id'])
  end.flatten.uniq

  match = foreman_smart_class_parameters.collect { |param| param['match'] }.uniq.first
  # WARNING:  Can have multiple puppetclasses
  puppetclass = foreman_smart_class_parameters.first['puppetclass']
  
  # Find all existing overrides that aren't in the new override list
  delete_smart_class_parameter_overrides = foreman_host_smart_class_parameters.collect do |param|
    override_values = param['override_values'].select do |override|
      next unless override['match'] == match
      next unless param['puppetclass'] == puppetclass
      foreman_smart_class_parameters.none? do |p| 
        p['puppetclass'] == param['puppetclass']['name'] && p['parameter']   == param['parameter']
      end
    end
  
    override_values.collect do |override_value| 
      { 
        'smart_class_parameter_id' => param['id'],
        'puppetclass'              => param['puppetclass']['name'],
        'parameter'                => param['parameter'],
        'override_value_id'        => override_value['id'],
        'match'                    => override_value['match'],
        'value'                    => override_value['value']
      }
    end
  end.flatten.compact

  $evm.log(:info, "Obsolete Foreman Smart Class Variables overrides: [#{delete_smart_class_parameter_overrides}]")
  delete_smart_class_parameter_overrides.collect { |x| x.slice('smart_class_parameter_id', 'override_value_id') }
end

begin
  dump_root()

  task = $evm.root['service_template_provision_task'] || $evm.root['service_reconfigure_task']
  attrs = task.get_option(:attrs)
  
  uri = "#{$evm.current_namespace}/#{$evm.current_class}/CustomizeForemanSmartClassParametersFor#{attrs[:state_machine]}"
  if $evm.instance_exists?(uri)
    $evm.log(:info, "Customizing Foreman Smart Class Parameters: [#{attrs[:state_machine]}]")
    results = instantiate(uri)
    
    delete_foreman_smart_class_parameter_overrides = collect_obsolete_smart_class_parameter_overrides(
      attrs[:infrastructure_environment],
      attrs[:foreman_environment_id],
      results['foreman_host_seach'], 
      results['foreman_smart_class_parameters']) unless results['foreman_host_seach'].blank?

    update_foreman_smart_class_parameters(
      task, 
      attrs[:infrastructure_environment], 
      attrs[:foreman_environment_id], 
      results['foreman_smart_class_parameters'],
      delete_foreman_smart_class_parameter_overrides) unless results['foreman_smart_class_parameters'].blank?
  end

rescue => err
  error("[#{err}]\n#{err.backtrace.join("\n")}")
end  

begin
  task = $evm.root['service_template_provision_task'] || $evm.root['service_reconfigure_task']
  service = task.destination
  dialog_options = task.options[:dialog]
  smart_class_parameters = setup_smart_class_overrides(dialog_options)

  # TODO: get parameters to delete and delete them
  
  # TODO: send smart_class_parameters to Foreman

rescue => err
  error("[#{err}]\n#{err.backtrace.join("\n")}")
end
