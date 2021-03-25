# frozen_string_literal: true

require File.expand_path('../../../util/k8s', __FILE__)
require 'tempfile'

Puppet::Type.type(:kubectl_apply).provide(:kubectl) do
  commands kubectl: 'kubectl'

  attr_reader :resource_diff

  def exists?
    data = kubectl_get
    return false unless data

    diff = content_diff(data)
    return true if resource[:ensure].to_s == 'absent' || resource[:update] == :false

    diff.empty?
  end

  def create
    tempfile = Tempfile.new('kubectl_apply')
    tempfile.write resource_hash.to_json
    if resource_diff
      kubectl_cmd 'patch', '-f', tempfile.path, '-p', resource_diff.to_json
    else
      kubectl_cmd 'create', '-f', tempfile.path
    end
  ensure
    tempfile.close!
  end

  def destroy
    kubectl_cmd 'delete', resource[:kind], resource[:name]
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

  def kubectl_get
    @data ||= kubectl_cmd 'get', resource[:kind], resource[:name], '--output', 'json'
    JSON.parse(@data)
  rescue
    {}
  end

  def kubectl_cmd(*args)
    params = []
    if resource[:namespace]
      params << '--namespace'
      params << resource[:namespace]
    end
    if resource[:kubeconfig]
      params << '--kubeconfig'
      params << resource[:kubeconfig]
    end

    kubectl(*params, *args)
  end
end