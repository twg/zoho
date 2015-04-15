require 'rubygems'
require 'minitest/autorun'
require 'fileutils'
require 'vcr'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'zoho'


class Minitest::Test
  def setup
    Zoho.configure do |config|
      config.api_key = '44fd8ab4cc5500006bc3a2952b0bde39'
    end
  end
end

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock
end


