# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::Proxy_auth' do
  describe 'valid proxy_auth' do
    %w[
      cert
      token
      incluster
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid proxy_auth' do
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
