# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::Timestamp' do
  describe 'valid RFC3339 timestamp' do
    [
      '2018-04-11T13:57:56Z',
      '1999-12-31T23:59:59.999+02:00',
      '1990-01-01T00:00:00Z',
      '1990-01-01t00:00:00+00:30',
      '1990-01-01t00:00:00-01:30',
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid RFC3339 timestamp' do
    [
      nil,
      [nil],
      [nil, nil],
      { 'foo' => 'bar' },
      {},
      '',
      '2018-04-11 13:57:56',
      '2018-04-11T13:57:56',
      '2018-04-11Z13:57:56',
      '2990-13-11T13:57:56Z',
      '2990-13-11T13:57:56Z+01:00',
      '1999-12-32T23:59:59.999+02:00',
      '1979-05-05T24:00:00Z',
      '1979-05-05T05:60:00Z',
      '1979-05-05T05:21:61Z',
      '1979-05-05T01:00Z',
      199,
      1_000,
    ].each do |value|
      describe value.inspect do
        it { is_expected.not_to allow_value(value) }
      end
    end
  end
end
