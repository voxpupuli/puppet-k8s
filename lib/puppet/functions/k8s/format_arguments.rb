# frozen_string_literal: true

# Formats a hash of arguments into something that can be passed to a kubernetes application
Puppet::Functions.create_function(:'k8s::format_arguments') do
  # @param arguments A hash of arguments to format
  #
  # @return [Array[String]] An array of formatted kubernetes arguments
  dispatch :k8s_format_arguments do
    param 'Hash[String,Data]', :arguments
    return_type 'Array[String]'
  end

  def k8s_format_value(value)
    case value
    when String, Numeric, TrueClass, FalseClass
      value
    when Array
      value.map { |data| k8s_format_value(data) }.join(',')
    when Hash
      value.map { |key, data| "#{key.tr('_', '-')}=#{k8s_format_value(data)}" }.join(',')
    else
      raise ArgumentError, "Unable to format #{value.inspect} (#{value.class})"
    end
  end

  def k8s_format_arguments(arguments)
    formatted = arguments.map do |argument, value|
      next if value.nil?

      "--#{argument.tr('_', '-')}=#{k8s_format_value(value)}"
    end
    formatted.compact
  end
end
