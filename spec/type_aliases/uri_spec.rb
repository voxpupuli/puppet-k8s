# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::URI' do
  describe 'valid uri' do
    [
      'unix:///tmp/application.socket',
      'tcp://192.168.0.1:88',
      'http://example.com',
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid uri' do
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
