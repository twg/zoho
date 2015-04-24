class Zoho::Error < StandardError
  ERROR_CODE_NO_MATCHING_RECORD = 4422

  attr_accessor :code
  attr_accessor :message

  def initialize(args = {})
    @code = '<Unknown>'
    @code = args[:code] if args.key? :code

    @message = 'Unspecified Error'
    @message = args[:message] if args.key? :message
  end
end

class Zoho::ErrorNonUnique < StandardError; end