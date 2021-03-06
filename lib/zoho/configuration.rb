# encoding: utf-8

class Zoho::Configuration

  attr_accessor :api_key
  attr_accessor :custom_modules_map
  attr_accessor :custom_fields_map
  attr_accessor :logger

  def initialize
    @api_key = nil
    @custom_modules_map = {}
    @custom_fields_map = {}
    @logger = nil
  end

end