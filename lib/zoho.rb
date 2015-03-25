require "zoho/version"
require "zoho/engine" if defined?(Rails)
require "zoho/configuration"

module Zoho
  class << self

    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end
    alias :config :configuration

  end
end
