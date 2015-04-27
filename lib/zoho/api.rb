require 'ox'
require 'logger'

class Zoho::Api

  USER_TYPES = {
    :all_users => 'AllUsers',
    :active_users => 'ActiveUsers',
    :deactive_users => 'DeactiveUsers',
    :admin_users => 'AdminUsers',
    :active_confirmed_admins => 'ActiveConfirmedAdmins'
  }

  class << self

    # get_users('email', 'jack@twg.ca', :active_users)
    def get_users(field = nil, value = nil, subset = :all_users)
      params = { 'type' => USER_TYPES[subset] }
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

      # the Zoho API returns a object if the result set has one item, but an
      # array if it has more than one. So based on the number of records returned
      # or the columns that have been requested to be returned, the structure
      # of the results is different. The code below will normalize the structure
      # to arrays either way 
      if response.key? "result"
        rows = response["result"][module_name]["row"]
        if rows.kind_of? Hash
          rows = [rows]
        end

        rows.map do |row|
          deserialized_structure = {}

          fields = row["FL"]
          if fields.kind_of? Hash
            fields = [fields]
          end

          fields.each do |attr|
            deserialized_structure[attr["val"]] = attr["content"]
          end 

          deserialized_structure
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

    def convert_lead(lead_id)
      doc = Ox::Document.new()
      
      module_element = Ox::Element.new('Potentials')
      doc << module_element

      row = Ox::Element.new('row')
      row[:no] = 1
      module_element << row
      
      element = Ox::Element.new('option')
      element[:val] = 'createPotential'
      element << 'false'
      row << element

      params = {
        'leadId' => lead_id,
        'xmlData' => Ox::dump(doc)
      }

      response = json_get('Leads', 'convertLead', params)

      if response.key? "success"
        # our current needs are only interested in the contact side of the 
        # lead conversion, but zoho converts to both contact and accounts:
        # see https://www.zoho.com/crm/help/leads/convert-leads.html
        # for some good documentation on the subject matter
        { 'zoho_id' => response["success"]["Contact"]["content"] }
      else
        check_for_json_error response

        # not sure what the problem is if it gets this far
        raise Zoho::Error
      end
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

      # in the Zoho API, all methods that query Zoho go through
      # a HTTP GET request that returns JSON data.
      # the JSON fragment that is returned is in a different structure 
      # for each API call
      def json_get(module_name, api_call, options = {})
        url = URI(create_zoho_url('json', module_name, api_call))

        params = required_api_parameters.merge(options)

        url.query = URI.encode_www_form(params)
        http_response = Net::HTTP.get_response(url)
        JSON.parse(http_response.body)
      end

      # in the Zoho API, all methods that insert/update the data
      # go through a HTTP POST request that accepts an XML Fragment
      # and returns an XML fragment.
      # So far, the XML Fragment that is returned is a standard format
      # so we can process all of the responses through this method
      # Additionally, note that any changes to the system are 
      # asynchronous and can take up to 2 minutes to be available
      # to queries (empirically, the actual amount seems to fluctuate quite
      # a bit)
      def xml_post(module_name, api_call, xml_document, options = {})
        url = URI(create_zoho_url('xml', module_name, api_call))
        
        params = required_api_parameters.merge({
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