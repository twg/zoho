require 'ox'

class Zoho::Api

  class << self

    def insert_records(module_name, attrs)
      xml = build_xml(module_name, attrs)
      result = post(module_name, 'insertRecords', xml)
      parse_result(result)
      return result
    end

    def update_records(module_name, attrs)
      xml = build_xml(module_name, attrs)
      result = post(module_name, 'updateRecords', xml, attrs['zoho_id'].to_s)
      parse_result(result)
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

    def post(module_name, api_call, xml_data, id = nil)
      url = URI(create_url(module_name, api_call))
      
      params = {
        'authtoken' => Zoho.configuration.api_key, 
        'scope' => 'crmapi', 
        'newFormat' => '1',
        'xmlData' => xml_data,
        'duplicateCheck' => 1 
      }

      params['id'] = id if id.present?
      
      response = Net::HTTP.post_form(url, params)
      return response.body
    end

    def parse_result(result)
      parsed_result = Ox.parse(result)

      code = parsed_result.root.nodes[0].nodes[0].text
      message = parsed_result.root.nodes[0].nodes[1].text
    
      if parsed_result.root.nodes[0].value == 'error'
        raise Zoho::Error, "Error #{code}: #{message}"
      elsif code == 'Record(s) already exists'
        raise Zoho::ErrorNonUnique, "#{code}"
      else
        #TODO: if successful return Zoho ID
        return true
      end      
    end

  end
end