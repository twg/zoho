require File.expand_path('../helper', __FILE__)

class ConfigurationTest < Minitest::Test

  def test_initialization_defaults
    config = Zoho::Configuration.new
    assert_equal nil, config.api_key
  end

  def test_initialization_overrides
    config = Zoho::Configuration.new
    config.api_key = '123abc'
    assert_equal config.api_key, '123abc'
  end

end