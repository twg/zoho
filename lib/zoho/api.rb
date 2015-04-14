require 'httmultiparty'
require 'rexml/document'
require 'net/http/post/multipart'
require 'net/https'

class Zoho::Api

  include HTTMultiParty

  def add_record(module_name, attrs)
    x = REXML::Document.new
    element = x.add_element module_name
    row = element.add_element 'row', {'no' => '1'}
    attrs.each_pair { |k, v| add_field(row, k, v, module_name) }
    r = self.class.post(create_url(module_name, 'insertRecords'),
                        :query => {:newFormat => 1, :authtoken => @auth_token,
                                   :scope => 'crmapi', :xmlData => x, :wfTrigger => 'true'},
                        :headers => {'Content-length' => '0'})
    check_for_errors(r)
    x_r = REXML::Document.new(r.body).elements.to_a('//recorddetail')
    to_hash(x_r, module_name)[0]
  end

  def build_xml()
    doc = Ox::Document.new()
    doc << Ox::Element.new(module_name)

    doc = REXML::Document.new
    element = doc.add_element module_name
    row = element.add_element 'row', {'no' => '1'}
    attrs.each_pair { |k, v| add_field(row, k, v, module_name) }
  end

  def create_url(module_name, api_call)
    "https://crm.zoho.com/crm/private/xml/#{module_name}/#{api_call}"
  end

  def check_for_errors(response)
    raise(RuntimeError, "Web service call failed with #{response.code}") unless response.code == 200
    x = REXML::Document.new(response.body)

    # updateRelatedRecords returns two codes one in the status tag and another in a success tag, we want the
    # code under the success tag in this case
    code = REXML::XPath.first(x, '//success/code') || code = REXML::XPath.first(x, '//code')

    # 4422 code is no records returned, not really an error
    # TODO: find out what 5000 is
    # 4800 code is returned when building an association. i.e Adding a product to a lead. Also this doesn't return a message
    raise(RuntimeError, "Zoho Error Code #{code.text}: #{REXML::XPath.first(x, '//message').text}.") unless code.nil? || ['4422', '5000', '4800'].index(code.text)

    return code.text unless code.nil?
    response.code
  end
end