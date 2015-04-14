require 'ox'

class Zoho::Api

  # Zoho::insert_records('Account', {

  # })

  class << self
    def insert_records(module_name, attrs)
      xml = build_xml(module_name, attrs)
      result = post(module_name, 'insertRecords', xml)
      return result
    end

    def build_xml(module_name, attrs)
      doc = Ox::Document.new()
      module_element = Ox::Element.new(module_name)
      row = Ox::Element.new('row')
      row[:no] = 1
      
      attrs.each_pair do |key, value|
        element = Ox::Element.new('FL')
        element[:val] = key.split.map(&:capitalize).join(' ')
        element << value.to_s
        row << element
      end

      module_element << row
      doc << module_element
      return Ox::dump(doc)
    end

    def create_url(module_name, api_call)
      "https://crm.zoho.com/crm/private/xml/#{module_name}/#{api_call}"
    end

    def post(module_name, api_call, xml_data)
      url = URI(create_url(module_name, api_call))
      response = Net::HTTP.post_form(url, 'authtoken' => Zoho.configuration.api_key, 'scope' => 'crmapi', 'newFormat' => '1', 'xmlData' => xml_data)
      return response.body
    end

    # def check_for_errors(response)
    #   raise(RuntimeError, "Web service call failed with #{response.code}") unless response.code == 200
    #   x = REXML::Document.new(response.body)

    #   # updateRelatedRecords returns two codes one in the status tag and another in a success tag, we want the
    #   # code under the success tag in this case
    #   code = REXML::XPath.first(x, '//success/code') || code = REXML::XPath.first(x, '//code')

    #   # 4422 code is no records returned, not really an error
    #   # TODO: find out what 5000 is
    #   # 4800 code is returned when building an association. i.e Adding a product to a lead. Also this doesn't return a message
    #   raise(RuntimeError, "Zoho Error Code #{code.text}: #{REXML::XPath.first(x, '//message').text}.") unless code.nil? || ['4422', '5000', '4800'].index(code.text)

    #   return code.text unless code.nil?
    #   response.code
    # end
  end
end