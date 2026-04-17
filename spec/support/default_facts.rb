# frozen_string_literal: true

if File.exist?(File.expand_path('../default_module_facts.yml', __dir__))
  module_facts = YAML.safe_load(File.read(File.expand_path('../default_module_facts.yml', __dir__))) || {}
  RSpec.configure do |c|
    c.default_facts = c.default_facts.merge(module_facts)
  end
end
