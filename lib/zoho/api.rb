require 'ox'
require 'logger'

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

class Zoho::Api

  class << self

    def search_users(field = nil, value = nil, subset = 'AllUsers')
      params = { 'type' => subset }
      params['searchColumn'] = field unless field.nil?
      params['searchValue'] = value unless value.nil?

      response = json_get('Users', 'getUsers', params)

      users = response["users"]["user"]
      if users.kind_of? Hash
        users = [users]
      end

      users
    end

    def search_records(module_name, criteria, options = {})
      serialized_criteria = "(" + (criteria.map do |k, v|
        "(#{k}:#{v})"
      end).join(',') + ")"

      params = { 'criteria' => serialized_criteria }.merge!(options)

      response = json_get_with_validation(module_name, 'searchRecords', params);

      if response.key? "result"
        rows = response["result"][module_name]["row"]
        if rows.kind_of? Hash
          rows = [rows]
        end

        rows.map do |row|
          deserialized = {}
          row["FL"].each do |attr|
            deserialized[attr["val"]] = attr["content"]
          end 
          deserialized
        end
      elsif response.key?("nodata") && response["nodata"]["code"].to_i == Zoho::Error::ERROR_CODE_NO_MATCHING_RECORD
        nil
      else
        # have no idea what happend here
        raise Zoho::Error
      end
    end

    def insert_records(module_name, attrs)
      xml = build_xml(module_name, attrs)
      params = { 'duplicateCheck' => 1 }

      result = xml_post(module_name, 'insertRecords', xml, params)

      message = result.locate('response/result/message')
      if !message.empty? && message[0].text == 'Record(s) already exists'
        raise Zoho::ErrorNonUnique, "#{message[0].text}" 
      end

      fields = result.locate('response/result/recorddetail/FL')
      zoho_id = fields.select do |f|
        f.attributes[:val] == 'Id'
      end

      if zoho_id.empty?
        # not sure what happened here
        raise Zoho::Error
      end

      { 'zoho_id' => zoho_id[0].text }
    end

    def update_records(module_name, id, attrs)
      xml = build_xml(module_name, attrs)
      params = { 'id' => id.to_s }

      xml_post(module_name, 'updateRecords', xml, params)
    
      true
    end

    def delete_records(module_name, id)
      response = json_get_with_validation(module_name, 'deleteRecords', { 'id' => id.to_s })

      true
    end

    private
      def required_api_parameters
        {
          'authtoken' => Zoho.configuration.api_key,
          'scope' => 'crmapi'
        }        
      end

      def create_zoho_url(format, module_name, api_call)
        "#{Zoho.configuration.root_url}/#{format}/#{module_name}/#{api_call}"
      end

      def check_for_xml_error(response)
        return unless !response.locate("response/error").empty?

        code = response.locate("response/error/code")
        code = code[0].text.to_i unless code.empty?

        message = response.locate("response/error/message")
        message = message[0].text unless message.empty?

        if !code.nil? && !message.nil? 
          raise Zoho::Error.new({ :code => code, :message => message })
        else
          raise Zoho::Error
        end 
      end

      def check_for_json_error(response)
        return unless response["response"].key? "error"
        raise Zoho::Error.new({
          :code => response["response"]["error"]["code"].to_i,
          :message => response["response"]["error"]["message"]
        })
      end

      def json_get_with_validation(module_name, api_call, options = {})
        response = json_get(module_name, api_call, options)

        check_for_json_error(response)

        return response["response"]
      end

      def json_get(module_name, api_call, options = {})
        url = URI(create_zoho_url('json', module_name, api_call))

        params = required_api_parameters.merge!(options)

        url.query = URI.encode_www_form(params)
        http_response = Net::HTTP.get_response(url)
        JSON.parse(http_response.body)
      end

      def xml_post(module_name, api_call, xml_document, options = {})
        url = URI(create_zoho_url('xml', module_name, api_call))
        
        params = required_api_parameters.clone.merge!({
          'newFormat' => '1',
          'xmlData'   => xml_document
        }).merge!(options)
        
        http_response = Net::HTTP.post_form(url, params)
        response = Ox.parse(http_response.body)

        check_for_xml_error(response)

        return response
      end

      def build_xml(module_name, attrs)
        doc = Ox::Document.new()
        module_element = Ox::Element.new(module_name)
        row = Ox::Element.new('row')
        row[:no] = 1
        
        attrs.each_pair do |key, value|
          element = Ox::Element.new('FL')
          element[:val] = key
          element << value.to_s
          row << element
        end

        module_element << row
        doc << module_element
        return Ox::dump(doc)
      end      
  end
end