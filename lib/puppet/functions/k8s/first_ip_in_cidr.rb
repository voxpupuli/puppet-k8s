Puppet::Functions.create_function(:'k8s::first_ip_in_cidr') do
  # @param cidr The CIDR to check
  #
  # @return [String] The first IP address in the CIDR
  dispatch :first_ip_in_cidr do
    param 'Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR]', :cidr
    return_type 'String'
  end

  require 'ipaddr'
  def first_ip_in_cidr(cidr)
    ip = IPAddr.new(cidr)

    ip.succ.to_s
  end
end
