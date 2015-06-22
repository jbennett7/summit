service = $evm.root['service']
if service.nil?
  $evm.log('error', "Service Object not found")
  exit MIQ_ABORT
end

result = 'ok'

$evm.log('info', "Checking if all child services are retired")
if service.all_service_children.count > 0
  result = 'retry'
end

$evm.log('info', "Checking if all vms are retired")
if service.vms.count > 0
  result = 'retry'
end

$evm.log('info', "Service: #{service.name} Resource retirement check returned <#{result}>")
case result
when 'retry'
  $evm.log('info', "Service: #{service.name} resource is not retired, setting retry.")
  $evm.root['ae_result']         = 'retry'
  $evm.root['ae_retry_interval'] = '1.minute'
when 'ok'
  $evm.log('info', "All resources are retired for service: #{service.name}. ")
  $evm.root['ae_result'] = 'ok'
end
