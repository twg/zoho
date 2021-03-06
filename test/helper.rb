require 'rubygems'
require 'simplecov'
require 'coveralls'
require 'logger'

SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  add_filter '/test/'
end

require 'minitest/spec'
require 'minitest/autorun'
require 'fileutils'
require 'vcr'


$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'zoho'


class Minitest::Test
  def setup
    Zoho.configure do |config|
      config.api_key = '4bc37ba80b66d9e520758f84a170513d'
      # config.logger = Logger.new(STDOUT)
    end
  end
end

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock
end


