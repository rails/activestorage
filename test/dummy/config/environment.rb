ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../../Gemfile', __dir__)
require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])

require "rails"
require "active_job/railtie"
require "action_controller/railtie"

Bundler.require(*Rails.groups)
require "active_storage"

class Dummy < Rails::Application
  config.secret_key_base = "test"
  config.active_storage.service = :local
end

# Initialize the DummyApp application.
Dummy.initialize!
