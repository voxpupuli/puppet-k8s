# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::Duration' do
  describe 'valid duration' do
    [
      '300ms',
      '-1.5h',
      '2h45m',
      '1h10m10s',
      '1µs',
      '1us',
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid duration' do
    [
      nil,
      [nil],
      [nil, nil],
      { 'foo' => 'bar' },
      {},
      '',
      's',
      '.5s',
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
