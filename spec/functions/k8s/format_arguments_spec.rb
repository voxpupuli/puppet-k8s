# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::format_arguments' do
  it { is_expected.not_to eq(nil) }
  it { is_expected.to run.with_params.and_raise_error(ArgumentError) }
  it { is_expected.to run.with_params('one').and_raise_error(ArgumentError) }
  it { is_expected.to run.with_params({ 'one' => 1 }).and_return(['--one=1']) }
  it { is_expected.to run.with_params({ 'str' => 'value' }).and_return(['--str=value']) }
  it { is_expected.to run.with_params({ 'bool' => true, 'arr' => ['arg','arg','arg'] }).and_return(['--bool=true', '--arr=arg,arg,arg']) }
  it { is_expected.to run.with_params({ 'hash' => { 'one' => 1, 'two' => 2 }}).and_return(['--hash=one=1,two=2']) }
  it { is_expected.to run.with_params({ 'complex_param' => false }).and_return(['--complex-param=false']) }
end
