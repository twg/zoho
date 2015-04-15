require 'ox'

class Zoho::Api

  class << self

    def insert_records(module_name, attrs)
      xml = build_xml(module_name, attrs)
      
      params = {
        'newFormat' => '1',
        'xmlData'   => xml,
        'duplicateCheck' => 1
      }

      result = post(module_name, 'insertRecords', params)
      parse_result(result)
      return result
    end

    def update_records(module_name, attrs)
      xml = build_xml(module_name, attrs)

      params = {
        'newFormat' => '1',
        'xmlData'   => xml,
        'id'        => attrs['zoho_id'].to_s
      }

      result = post(module_name, 'updateRecords', params)
      parse_result(result)
      return result
    end

    def delete_records(module_name, id)
      result = post(module_name, 'deleteRecords', {'id' => id.to_s})
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

    def post(module_name, api_call, options = {})
      url = URI(create_url(module_name, api_call))
      
      params = {
        'authtoken' => Zoho.configuration.api_key,
        'scope' => 'crmapi'
      }.merge!(options)
      
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