require 'ox'

class Zoho::Api

  ZOHO_ROOT_URL = 'https://crm.zoho.com/crm/private'

  SEARCH_TYPES = {
    :all_users => 'AllUsers',
    :active_users => 'ActiveUsers',
    :deactive_users => 'DeactiveUsers',
    :admin_users => 'AdminUsers',
    :active_confirmed_admins => 'ActiveConfirmedAdmins'
  }

  class << self

    # field = The Zoho Field to search over.
    # value = The value to search for.
    # filter_by = The subset of users to search over
    #   the full list and their description is available here: https://www.zoho.com/crm/help/api/getusers.html  
    # e.g. get_users('email', 'phil.coulson@twg.ca', :active_users)
    def get_users(field = nil, value = nil, filter_by = :all_users)
      params = { 'type' => SEARCH_TYPES[filter_by] }
      params['searchColumn'] = field unless field.nil?
      params['searchValue'] = value unless value.nil?

      response = json_get('Users', 'getUsers', params)

      normalize_hash_array response["users"]["user"]
    end

    def get_record_by_id(module_name, id, options = {})
      params = { 'id' => id }.merge!(options)

      response = json_get_with_validation(module_name, 'getRecordById', params)

      process_query_response module_name, response
    end

    def get_records_by_ids(module_name, id_list, options = {})
      params = { 'idlist' => id_list.join(';') }.merge!(options)

      response = json_get_with_validation(module_name, 'getRecordById', params)

      process_query_response module_name, response
    end

    def get_records(module_name, from_index = 1, to_index = 20, options = {})
      return nil if from_index < 1
      return nil if from_index > to_index
      return nil if (to_index - from_index) > 200  

      params = {
        'fromIndex' => from_index,
        'toIndex' => to_index
      }.merge!(options)

      response = json_get_with_validation(module_name, 'getRecords', params)

      process_query_response module_name, response
    end

    # getSearchRecords (https://www.zoho.com/crm/help/api/getsearchrecords.html)
    # is a somewhat hidden API method that performs a synchronous search. i.e.
    # data is going to be there if it was recently inserted.
    # Compare and contrast this with the searchRecords method of the API.
    def search_records_sync(module_name, search_field, search_operator, search_value, select_columns = 'All', options = {})
      serialized_criteria = "(#{map_custom_field_name(module_name, search_field)}|#{search_operator}|#{search_value})"

      params = {
        'selectColumns' => select_columns,
        'searchCondition' => serialized_criteria
      }.merge!(options)

      response = json_get_with_validation(module_name, 'getSearchRecords', params)

      process_query_response module_name, response
    end

    # searchRecords (https://www.zoho.com/crm/help/api/searchrecords.html)
    # is an API method that performs an async search. i.e. data may not show
    # up if it was inserted/updated in the last one or two minutes. 
    # These requests DO NOT count against the API request limit.
    # Compare and contrast this with the getSearchRecords method of the API.
    def search_records_async(module_name, criteria, options = {})
      serialized_criteria = "(" + (criteria.map do |k, v|
        "(#{map_custom_field_name(module_name, k)}:#{v})"
      end).join(',') + ")"

      params = { 'criteria' => serialized_criteria }.merge!(options)

      response = json_get_with_validation(module_name, 'searchRecords', params);

      process_query_response module_name, response
    end

    def insert_records(module_name, attrs, options = {})
      xml = build_xml(module_name, attrs)
      params = { 'duplicateCheck' => 1 }.merge!(options)

      result = xml_post(module_name, 'insertRecords', xml, params)

      message = result.locate('response/result/message')
      if !message.empty? && message[0].text == 'Record(s) already exists'
        raise Zoho::ErrorNonUnique, "#{message[0].text}" 
      end

      fields = result.locate('response/result/recorddetail/FL')
      zoho_id = fields.select do |f|
        f.attributes[:val] == 'Id'
      end

      { 'zoho_id' => zoho_id[0].text }
    end

    def update_records(module_name, id, attrs, options = {})
      xml = build_xml(module_name, attrs)
      params = { 'id' => id.to_s }.merge!(options)

      xml_post(module_name, 'updateRecords', xml, params)
    
      true
    end

    def delete_records(module_name, id, options = {})
      params = { 'id' => id.to_s }.merge!(options)

      response = json_get_with_validation(module_name, 'deleteRecords', params)

      true
    end

    def convert_lead(lead_id, options = {})
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
      params.merge!(options)

      response = json_get('Leads', 'convertLead', params)

      if response.key? "success"
        # See https://www.zoho.com/crm/help/leads/convert-leads.html
        # for some good documentation on what happens when you convert a lead
        { 
          'zoho_contact_id' => response["success"]["Contact"]["content"],
          'zoho_account_id' => response["success"]["Account"]["content"] 
        }
      else
        check_for_json_error response
      end
    end

    private
      def required_api_parameters 
        {
          'authtoken' => Zoho.configuration.api_key,
          'scope' => 'crmapi'
        }
      end

      # Custom Modules in Zoho have names that are simply assigned out
      # by the system (usually in the form CustomModulen). Route all
      # module name resolutions through this function to get some clarity
      # back
      def map_custom_module_name(custom_module_name)
        Zoho.configuration.custom_modules_map[custom_module_name] || custom_module_name
      end

      def map_custom_field_name(custom_module_name, custom_field_name)
        map = Zoho.configuration.custom_fields_map[custom_module_name] ||= {}
        map[custom_field_name] || custom_field_name
      end

      def unmap_custom_field_name(custom_module_name, field_name)
        map = Zoho.configuration.custom_fields_map[custom_module_name] ||= {}
        map.key(field_name) || field_name
      end

      # the Zoho API returns a hash if the result set has one item, but an
      # array if it has more than one. So based on the number of records returned
      # or the columns that have been requested to be returned, the structure
      # of the results is different. The code below will normalize the structure
      # to arrays either way 
      def normalize_hash_array(record)
        if record.kind_of? Hash
          [record]
        else
          record
        end
      end

      # converts the Zoho response structure into an array of hashes
      # where keys are the field names, and values are the field values
      def process_query_response(module_name, response)
        if response.key? "result"
          rows = normalize_hash_array response["result"][map_custom_module_name(module_name)]["row"]

          rows.map do |row|
            normalized_structure = {}

            fields = normalize_hash_array row["FL"]

            fields.each do |attr|
              normalized_structure[unmap_custom_field_name(module_name, attr["val"])] = attr["content"]
            end 

            normalized_structure
          end
        elsif response.key?("nodata") && response["nodata"]["code"].to_i == Zoho::Error::ERROR_CODE_NO_MATCHING_RECORD
          nil
        end
      end      

      def create_zoho_url(format, module_name, api_call)
        "#{ZOHO_ROOT_URL}/#{format}/#{map_custom_module_name(module_name)}/#{api_call}"
      end

      def check_for_xml_error(response)
        return unless !response.locate("response/error").empty?

        code = response.locate("response/error/code")
        code = code[0].text.to_i unless code.empty?
        code ||= -1

        message = response.locate("response/error/message")
        message = message[0].text unless message.empty?
        message ||= 'An unexpected error happend.'

        raise Zoho::Error.new({ :code => code, :message => message })
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
        module_element = Ox::Element.new(map_custom_module_name(module_name))
        row = Ox::Element.new('row')
        row[:no] = 1
        
        attrs.each_pair do |key, value|
          element = Ox::Element.new('FL')
          element[:val] = map_custom_field_name(module_name, key)
          element << value.to_s
          row << element
        end

        module_element << row
        doc << module_element
        
        Ox::dump(doc)
      end      
  end
end