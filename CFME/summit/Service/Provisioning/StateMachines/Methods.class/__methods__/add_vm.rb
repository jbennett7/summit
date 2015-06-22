def build_request(task, template_options, vm_options, tag_options, ws_options)
  user = $evm.root['user']
  user_id    = user ? user.userid : "admin"
  user_email = user ? user.email : "admin@example.com"
  first = "admin"
  last  = "admin"

  build_request = {}
  build_request[:version] = '1.1'
  build_request[:template_fields] = template_options.collect { |k, v| "#{k}=#{v}"}.join('|')
  build_request[:vm_fields] = vm_options.collect { |k, v| "#{k}=#{v}"}.join('|')
  build_request[:requester] = "user_name=#{user_id}|owner_first_name=#{first}|owner_last_name=#{last}|owner_email=#{user_email}"
  build_request[:tags] = tag_options.collect { |k, v| "#{k}=#{v}"}.join('|')
  build_request[:ws_values] = ws_options.collect { |k, v| "#{k}=#{v}"}.join('|')
  build_request[:ems_custom_attributes] = nil
  build_request[:miq_custom_attributes] = nil

  $evm.log("info", "Building provisioning request with the following arguments: [#{build_request}]")
  task.miq_request.set_option(:build_request, build_request)

  $evm.execute(
    'create_provision_request',
    build_request[:version], build_request[:template_fields],
    build_request[:vm_fields], build_request[:requester],
    build_request[:tags], build_request[:ws_values],
    build_request[:ems_custom_attributes], build_request[:miq_custome_attributes])
end

$evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{k}: #{v}") }

service = $evm.root['service']
task = $evm.vmdb('service_template_provision_task').find_by_destination_id(service.id)
dialog_options = task.options[:dialog]
template = $evm.vmdb('miq_template').find_by_name('rhel-blank-template')
$evm.log("info", "Service #{service}")
$evm.log("info", "Task #{task}")
$evm.log("info", "Dialog Options #{dialog_options}")

template_options = {}
template_options[:guid] = template.guid
template_options[:request_type] = 'template'

vm_options = {}
vm_options[:provision_type] = 'native_clone'
vm_options[:vm_auto_start] = false
vm_options[:vlan] = dialog_options['dialog_subnet']
vm_options[:vm_memory] = dialog_options['dialog_vm_memory']
vm_options[:number_of_sockets] = dialog_options['dialog_number_of_sockets']
vm_options[:cores_per_socket] = dialog_options['dialog_cores_per_socket']

ws_options = {}
ws_options[:hostgroup] = dialog_options['dialog_hostgroup']
ws_options[:service_id] = service.id
ws_options[:service_name] = dialog_options['dialog_service_name']

tag_options = {}

instance_count = $evm.root['dialog_instance_count'].to_i

(1..instance_count).each do |instance|
  $evm.log("info", "Instance Count #{instance}")
  build_request(
    task,
    template_options,
    vm_options.merge({:vm_name => "#{dialog_options['dialog_service_name']}-$n{1}.#{dialog_options['dialog_domain_name']}".downcase}),
    tag_options,
    ws_options.merge({:instance => instance})
  )
end

