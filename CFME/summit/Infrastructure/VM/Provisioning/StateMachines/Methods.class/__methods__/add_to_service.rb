prov = $evm.root['miq_provision']
vm = prov.vm
service_id = prov.options[:ws_values][:service_id]
service = $evm.vmdb('service').find_by_id(service_id)
user = $evm.root['user']

if service && vm
  $evm.log("info", "Attaching Service to VM: [#{service.name}][#{vm.name}]")
  vm.add_to_service(service)

  vm.owner = user if user
  vm.group = user.miq_group if user
end
