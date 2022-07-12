# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::PortRange' do
  describe 'valid port range' do
    [
      '80',
      '443',
      '9090-9099',
      '1-5'
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid port range' do
    [
      nil,
      [nil],
      [nil, nil],
      { 'foo' => 'bar' },
      {},
      '',
      '-5',
      '0.2'
    ].each do |value|
      describe value.inspect do
        it { is_expected.not_to allow_value(value) }
      end
    end
  end
end
