def service_setup_one(service_name, service)
  check_service = $evm.vmdb('service').find_by_name(service_name)
  if check_service
    $evm.log("info", "Found Service #{check_service}")
    service = check_service
  else
    $evm.log("info", "Creating Service #{service_name}")
    service.name = service_name
    service.display = true
    service.owner = user if user
    service.group = user.current_group if user
  end
end

def service_setup_two(service_name, service)
  parent_service = $evm.vmdb('service').find_by_name(service_name)
  unless parent_service
    $evm.log("info", "Creating Parent Service #{service_name}")
    parent_service = $evm.vmdb('service').create(:name => service_name)
    parent_service.display = true
  end
  service.parent_service = parent_service
end

task = $evm.root['service_template_provision_task']
service = task.destination
dialog_options = task.options[:dialog]
user = $evm.root['user']

service_name = "#{dialog_options['dialog_service_name'].downcase}"
service_setup_two(service_name, service)
