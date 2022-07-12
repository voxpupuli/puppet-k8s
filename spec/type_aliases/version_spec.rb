# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::Version' do
  describe 'valid version' do
    [
      '1.25.0',
      '1.13.4',
      '1.999.4',
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid version' do
    [
      nil,
      [nil],
      [nil, nil],
      { 'foo' => 'bar' },
      {},
      '',
      '1.20',
      '5.5.5.5',
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
