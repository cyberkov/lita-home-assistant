# frozen_string_literal: true
require 'simplecov'
require 'webmock/rspec'
SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter
]
SimpleCov.start { add_filter '/spec/' }

require 'lita-home-assistant'
require 'lita/rspec'

Lita.version_3_compatibility_mode = false

WebMock.disable_net_connect!(allow_localhost: true)
require 'support/fake_homeassistant'
RSpec.configure do |config|
  config.before(:each) do
    stub_request(:any, /127.0.0.1/).to_rack(FakeHomeAssistant)
  end
end
