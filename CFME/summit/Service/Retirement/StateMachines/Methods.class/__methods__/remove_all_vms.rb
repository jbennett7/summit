service = $evm.root['service']

$evm.log("info", "Retiring all VMs from this service Total: #{service.vms.count} VMs")

service.vms.each do |vm|
  vm.retire_now unless vm.retirement_state == "retiring"
end
