# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::Addn_names' do
  describe 'valid addn_names' do
    [
      [nil],
      ['1.2.3.4'],
      ['2001:db8:3333:4444:5555:6666:7777:8888'],
      ['www.example.com'],
      ['fullname']
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid addn_names' do
    [
      nil,
      { 'foo' => 'bar' },
      {},
      '',
      'mailto:',
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
