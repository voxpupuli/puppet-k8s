# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::Node_role' do
  describe 'valid node_role' do
    %w[
      node
      server
      control-plane
      etcd-replica
      none
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid node_role' do
    [
      nil,
      [nil],
      [nil, nil],
      { 'foo' => 'bar' },
      {},
      '',
      's',
      'mailto:',
      'blah',
      '199',
      600,
      1_000,
    ].each do |value|
      describe value.inspect do
        it { is_expected.not_to allow_value(value) }
      end
    end
  end
end
