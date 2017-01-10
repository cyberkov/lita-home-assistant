# frozen_string_literal: true
Gem::Specification.new do |spec|
  spec.name          = 'lita-home-assistant'
  spec.version       = '0.1.0'
  spec.authors       = ['Hannes Schaller']
  spec.email         = ['admin@cyberkov.at']
  spec.description   = 'Interact with home-assistant through lita.io'
  spec.summary       = 'Interact with home-assistant through lita.io'
  spec.homepage      = 'https://github.com/cyberkov/lita-home-assistant'
  spec.license       = 'GPL-3.0+'
  spec.metadata      = { 'lita_plugin_type' => 'handler' }

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.1'

  spec.add_runtime_dependency 'lita', '>= 4.7'
  spec.add_runtime_dependency 'fuzzy_match'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rspec', '>= 3.0.0'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'sinatra'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'pry'
end
