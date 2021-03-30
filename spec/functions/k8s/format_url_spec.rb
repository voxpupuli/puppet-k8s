# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::format_url' do
  it { is_expected.not_to eq(nil) }
  it { is_expected.to run.with_params.and_raise_error(ArgumentError) }
  it { is_expected.to run.with_params('one').and_raise_error(ArgumentError) }
  it { is_expected.to run.with_params('format %{one}', { 'one' => 1 }).and_return('format 1') }
end
