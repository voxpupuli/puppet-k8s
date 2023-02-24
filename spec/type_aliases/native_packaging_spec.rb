# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::Native_packaging' do
  describe 'valid native_packaging' do
    [
      'package',
      'tarball',
      'loose',
      'hyperkube',
      'manual'
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid native_packaging' do
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
