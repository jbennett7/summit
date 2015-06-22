service = $evm.root['service']
instance_count = $evm.root['dialog_instance_count']


list = service.direct_vms.sort_by do |vm|
  vm.created_on
end

$evm.log("info", "List of VMs associated with this service")
list.each { |vm| $evm.log("info", "VM:  #{vm.name} #{vm.created_on}") }

(0..instance_count.to_i-1).each do |idx|
  list[idx].retire_now unless list[idx].retirement_state == "retiring"
end
