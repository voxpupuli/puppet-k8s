# frozen_string_literal: true

Puppet::Functions.create_function(:'k8s::format_arguments') do
  # Format a hash of arguments into something that can be passed to a kubernetes application
  #
  # @param arguments A hash of arguments to format
  #
  # @return [Array[String]] An array of formatted kubernetes arguments
  dispatch :k8s_format_arguments do
    param 'Hash[String,Data]', :arguments
    return_type 'Array[String]'
  end

  def k8s_format_value(value)
    case value.class
    when String, Numeric, TrueClass, FalseClass
      value.inspect
    when Array
      value.map { |data| k8s_format_value(data) }.join(',')
    when Hash
      value.map do |key, data|
        "#{key.tr('_', '-')}=#{k8s_format_value(data)}"
      end
    else
      raise ArgumentError, "Unable to format #{value.inspect} (#{value.class})"
    end
  end

  def k8s_format_arguments(arguments)
    arguments.map do |argument, value|
      "--#{argument.tr('_', '-')}=#{k8s_format_value(value)}".join ' '
    end
  end
end
