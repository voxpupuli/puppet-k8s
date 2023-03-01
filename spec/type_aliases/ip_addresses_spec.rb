# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::IP_addresses' do
  describe 'valid IP addresses' do
    [
      '1.2.3.4',
      '2001:db8:3333:4444:5555:6666:7777:8888',
      ['1.2.3.4'],
      ['2001:db8:3333:4444:5555:6666:7777:8888'],
      ['1.2.3.4', '2001:db8:3333:4444:5555:6666:7777:8888'],
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid IP addresses' do
    [
      nil,
      [nil],
      [nil, nil],
      [],
      { 'foo' => 'bar' },
      {},
      '',
      [''],
      ['s'],
      ['mailto:'],
      ['blah'],
      ['199'],
      600,
      1_000,
    ].each do |value|
      describe value.inspect do
        it { is_expected.not_to allow_value(value) }
      end
    end
  end
end
