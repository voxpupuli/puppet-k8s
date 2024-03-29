# frozen_string_literal: true

require 'spec_helper'

describe 'K8s::TLS_altnames' do
  describe 'valid TLS altnames' do
    [
      [],
      ['1.2.3.4'],
      ['2001:db8:3333:4444:5555:6666:7777:8888'],
      ['::1'],
      ['www.example.com'],
      ['fullname'],
      ['127.0.0.1', '::1', 'localhost']
    ].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid TLS altnames' do
    [
      [nil],
      nil,
      { 'foo' => 'bar' },
      {},
      '',
      [''],
      ['mailto:'],
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
