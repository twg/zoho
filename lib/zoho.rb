require 'net/http'
require 'net/https'

require "zoho/version"
require "zoho/engine" if defined?(Rails)
require "zoho/error"
require "zoho/api"
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
