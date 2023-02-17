# frozen_string_literal: true

# Retrieves an IP inside of a CIDR based on an index
Puppet::Functions.create_function(:'k8s::ip_in_cidr') do
  # @example In 192.168.0.0/24
  #     k8s::ip_in_cidr('192.168.0.0/24', 'first')
  #     # => 192.168.0.1
  #     k8s::ip_in_cidr('192.168.0.0/24', 'second')
  #     # => 192.168.0.2
  #     k8s::ip_in_cidr('192.168.0.0/16', 600)
  #     # => 192.168.1.244
  #
  # @param cidr The CIDR to work on
  # @param index The index of the IP to retrieve
  #
  # @return [String] The first IP address in the CIDR
  dispatch :ip_in_cidr do
    param 'Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR, Array[Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR]]]', :cidr
    optional_param 'Variant[Enum["first","second"], Integer[1]]', :index
    return_type 'String'
  end

  require 'ipaddr'
  def ip_in_cidr(cidr, index = 1)
    cidr = cidr.first if cidr.is_a? Array

    if index.is_a? String
      index = 1 if index == 'first'
      index = 2 if index == 'second'
    end

    ip = IPAddr.new(cidr)

    width = ip.ipv4? ? 32 : 128
    raise ArgumentError, 'Index is outside of the CIDR' if index >= 2**(width - ip.prefix)

    index.times { ip = ip.succ }

    ip.to_s
  end
end
