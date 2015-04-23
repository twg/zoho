# encoding: utf-8

class Zoho::Configuration

  attr_accessor :api_key
  attr_accessor :root_url

  def initialize
    @api_key = nil
    @root_url = 'https://crm.zoho.com/crm/private'
  end

end