# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::Cidr' do
  describe 'valid cidr' do
    [
      '1.2.3.4/8',
      '2001:db8:3333:4444:5555:6666:7777:8888/32',
      ['1.2.3.4/8'],
      ['2001:db8:3333:4444:5555:6666:7777:8888/32'],
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid cidr' do
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
