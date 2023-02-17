# frozen_string_literal: true

require 'spec_helper'

describe 'k8s::format_url' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.not_to eq(nil) }
      it { is_expected.to run.with_params.and_raise_error(ArgumentError) }
      it { is_expected.to run.with_params('one').and_raise_error(ArgumentError) }
      it { is_expected.to run.with_params('format %{one}', { 'one' => 1 }).and_return('format 1') }
    end
  end
end
