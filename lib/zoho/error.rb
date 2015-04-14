class Zoho::Error < StandardError
  attr_accessor :error_code, :error_message

  def initialize(code, message)
    @error_code = code
    @error_message = message
    raise self, "Error #{@error_code}: #{@error_message}"
  end


end