# frozen_string_literal: true

require File.expand_path('../../../util/k8s', __FILE__)

Puppet::Type.type(:kubectl_apply).provide(:file) do
  attr_reader :resource_diff

  def exists?
    data = file_get
    return false unless data

    diff = content_diff(data)
    return true if resource[:ensure].to_s == 'absent' || resource[:update] == :false

    diff.empty?
  end

  def create
    File.write resource[:file], resource_hash.to_json
  end

  def destroy
    Fileutils.rm resource[:file]
  end

  def content_diff(content, store: true)
    diff = Puppet::Util::K8s.content_diff(resource[:content], content)

    @resource_diff = diff if store
    diff
  end

  def resource_hash
    hash = resource[:content]

    hash['apiVersion'] = resource[:api_version]
    hash['kind'] = resource[:kind]

    metadata = hash['metadata'] ||= {}
    metadata['name'] = resource[:name]
    metadata['namespace'] = resource[:namespace] if resource[:namespace]

    hash
  end

  private

  def file_get
    return nil unless File.exist? resource[:file]

    JSON.parse(File.read(resource[:file]))
  rescue
    {}
  end
end
