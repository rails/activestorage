require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)
require "active_storage"

module Dummy
  class Application < Rails::Application
    config.load_defaults 5.1

    config.active_storage.service = :local
  end
end

