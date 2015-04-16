require File.expand_path('../helper', __FILE__)

describe "initialization defaults" do
  before do
    @config = Zoho::Configuration.new
  end

  it "has correct default initialization values" do
    assert_equal nil, @config.api_key
  end 

  it "overrides default initialization values" do
    @config.api_key = '123abc'
    assert_equal '123abc', @config.api_key
  end 
end