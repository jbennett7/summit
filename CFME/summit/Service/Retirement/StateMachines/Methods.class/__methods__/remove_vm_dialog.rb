require 'set'

service = $evm.root['service']

instances = Set.new
(1..service.direct_vms.count).each do |idx|
  instances << idx.to_s
end

list_values = {
  'sort_by'    => :none,
  'data_type'  => :string,
  'required'   => false,
  'values'     => [[nil, nil]] + instances.collect { |x| x.reverse }.sort 
}

$evm.log('info', "Remove VM drop-down: [#{list_values}]")
list_values.each { |k,v| $evm.object[k] = v }

exit MIQ_OK
