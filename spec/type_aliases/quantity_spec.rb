# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::Quantity' do
  describe 'valid quantity' do
    [
      '1',
      '-52.3',
      '200Mi',
      '20m',
      '3.33T',
      '+4e5',
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid quantity' do
    [
      nil,
      [nil],
      [nil, nil],
      { 'foo' => 'bar' },
      {},
      '',
      'm',
      'Mi',
      '.5s',
      'blah',
    ].each do |value|
      describe value.inspect do
        it { is_expected.not_to allow_value(value) }
      end
    end
  end
end
