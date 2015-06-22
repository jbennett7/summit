service = $evm.root['service']

service.all_service_children.each do |svc|
  $evm.log('info',"Retiring service #{svc.name}")
  svc.retire_now unless svc.retirement_state == "retiring"
end
