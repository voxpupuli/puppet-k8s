# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::Bootstrap_token' do
  describe 'valid bootstrap_token' do
    %w[
      0000000000000000
      0123456788abcdef
      st62jgvado5wmxq0
      eurx5qsdwf9z3v7t
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid bootstrap_token' do
    [
      nil,
      [nil],
      [nil, nil],
      { 'foo' => 'bar' },
      {},
      '',
      's',
      'mailto:',
      '58QLY1G3RASKBJTC',
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
