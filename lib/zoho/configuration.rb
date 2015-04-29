# encoding: utf-8

class Zoho::Configuration

  attr_accessor :api_key
  attr_accessor :custom_modules_map

  def initialize
    @api_key = nil
    @custom_modules_map = {}
  end

end