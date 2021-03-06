require 'ox'

class Zoho::Api

  ZOHO_ROOT_URL = 'https://crm.zoho.com/crm/private'
  ZOHO_MAX_RECORDS_MANIPULATION = 100
  ZOHO_MAX_RECORDS_RETRIEVE = 200

  SEARCH_TYPES = {
    :all_users => 'AllUsers',
    :active_users => 'ActiveUsers',
    :deactive_users => 'DeactiveUsers',
    :admin_users => 'AdminUsers',
    :active_confirmed_admins => 'ActiveConfirmedAdmins'
  }

  class << self

    def log(msg)
      return if Zoho.configuration.logger.nil?
      Zoho.configuration.logger.info msg
    end

    # field = The Zoho Field to search over.
    # value = The value to search for.
    # filter_by = The subset of users to search over
    #   the full list and their description is available here: https://www.zoho.com/crm/help/api/getusers.html
    # e.g. get_users('email', 'phil.coulson@twg.ca', :active_users)
    def get_users(field = nil, value = nil, filter_by = :all_users)
      log "get_users field=#{field}, value=#{value}, filter_by=#{filter_by}"

      params = { 'type' => SEARCH_TYPES[filter_by] }
      params['searchColumn'] = field unless field.nil?
      params['searchValue'] = value unless value.nil?

      response = json_get('Users', 'getUsers', params)

      normalize_hash_array response["users"]["user"]
    end

    def get_record_by_id(module_name, id, options = {})
      log "get_record_by_id module_name=#{module_name}, id=#{id}, options=#{options}"

      params = { 'id' => id }.merge!(options)

      response = json_get_with_validation(module_name, 'getRecordById', params)

      p = process_query_response module_name, response

      p[0] unless p.nil?
    end

    def get_records_by_ids(module_name, id_list, options = {})
      log "get_records_by_ids module_name=#{module_name}, id_list=#{id_list}, options=#{options}"

      params = { 'idlist' => id_list.join(';') }.merge!(options)

      response = json_get_with_validation(module_name, 'getRecordById', params)

      process_query_response module_name, response
    end

    def get_records(module_name, from_index = 1, to_index = 20, options = {})
      log "get_records module_name=#{module_name}, from_index=#{from_index}, to_index=#{to_index}, options=#{options}"

      return nil if from_index < 1
      return nil if from_index > to_index
      return nil if (to_index - from_index) > ZOHO_MAX_RECORDS_RETRIEVE

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
    # NOTE: This API method is deprecated and has a low API usage counter
    def search_records_sync(module_name, search_field, search_operator, search_value, select_columns = 'All', options = {})
      log "search_records_sync module_name=#{module_name}, search_field=#{search_field}, search_operator=#{search_operator}, search_value=#{search_value}, select_columns=#{select_columns}, options=#{options}"

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
    # up if it was inserted/updated in the last one or two minutes
    # (empirically, the actual amount seems to fluctuate quite a bit).
    # Compare and contrast this with the getSearchRecords method of the API.
    def search_records_async(module_name, criteria, options = {})
      log "search_records_async module_name=#{module_name}, criteria=#{criteria}, options=#{options}"

      serialized_criteria = "(" + (criteria.map do |k, v|
        "(#{map_custom_field_name(module_name, k)}:#{v})"
      end).join(',') + ")"

      params = { 'criteria' => serialized_criteria }.merge!(options)

      response = json_get_with_validation(module_name, 'searchRecords', params)

      process_query_response module_name, response
    end

    def insert_record(module_name, attrs, options = {})
      results = insert_records(module_name, [attrs], options)

      if results[1].is_a? Zoho::Error
        raise results[1]
      else
        results[1]
      end
    end

    def insert_records(module_name, records, options = {})
      log "insert_records module_name=#{module_name}, records=#{records}, options=#{options}"

      params = { 'duplicateCheck' => 1, 'version' => 4 }.merge!(options)

      stride = 0

      results = {}

      records.each_slice(ZOHO_MAX_RECORDS_MANIPULATION) do |slice|
        xml = build_xml(module_name, slice)

        response = xml_post(module_name, 'insertRecords', xml, params)

        rows = response.locate('response/result/row')

        rows.each do |row|
          row_number = row.attributes[:no].to_i + stride

          code = row.locate('success/code')
          if !code.empty? && code[0].text == '2002'
            #2002 comes from the Zoho code for duplicate
            # (https://www.zoho.com/crm/help/api/insertrecords.html#Version4)
            results[row_number] = Zoho::ErrorNonUnique.new
          else
            code = row.locate('error/code')
            message = row.locate('error/details')

            if !code.empty?
              code = code[0].text.to_i unless code.empty?
              code ||= -1

              message = message[0].text unless message.empty?
              message ||= 'An unexpected error happend.'

              log "insert_records encountered Zoho Exception #{code}: #{message}"

              results[row_number] = Zoho::Error.new({ :code => code, :message => message })
            else
              fields = row.locate('success/details/FL')

              if !fields.empty?
                zoho_id = fields.select do |f|
                  f.attributes[:val] == 'Id'
                end

                results[row_number] = zoho_id[0].text
              end
            end
          end
        end

        stride += ZOHO_MAX_RECORDS_MANIPULATION
      end

      results
    end

    def update_record(module_name, id, attrs, options = {})
      attrs['Id'] = id

      results = update_records(module_name, [attrs], options)

      results[1]
    end

    def update_records(module_name, records, options = {})
      log "update_records module_name=#{module_name}, records=#{records}, options=#{options}"

      params = { 'version' => 4 }.merge!(options)

      stride = 0

      results = {}

      records.each_slice(ZOHO_MAX_RECORDS_MANIPULATION) do |slice|
        xml = build_xml(module_name, slice)

        response = xml_post(module_name, 'updateRecords', xml, params)

        rows = response.locate('response/result/row')

        rows.each do |row|
          row_number = row.attributes[:no].to_i + stride

          code = row.locate('success/code')
          if !code.empty? && code[0].text == '2001'
            results[row_number] = true
          else
            code = row.locate('error/code')
            code = code[0].text.to_i unless code.empty?
            code ||= -1

            message = row.locate('error/details')
            message = message[0].text unless message.empty?
            message ||= 'An unexpected error happend.'

            log "update_records encountered Zoho Exception #{code}: #{message}"

            results[row_number] = Zoho::Error.new({ :code => code, :message => message })
          end
        end

        stride += ZOHO_MAX_RECORDS_MANIPULATION
      end

      results
    end

    def delete_record(module_name, id, options = {})
      log "delete_record module_name=#{module_name}, id=#{id}, options=#{options}"

      params = { 'id' => id.to_s }.merge!(options)

      response = json_get_with_validation(module_name, 'deleteRecords', params)

      true
    end

    def convert_lead(lead_id, options = {})
      log "convert_lead lead_id=#{lead_id}, options=#{options}"

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
        return unless !response.locate('response/error').empty?

        code = response.locate('response/error/code')
        code = code[0].text.to_i unless code.empty?
        code ||= -1

        message = response.locate('response/error/message')
        message = message[0].text unless message.empty?
        message ||= 'An unexpected error happend.'

        log "Zoho Exception (#{code}): #{message}."

        raise Zoho::Error.new({ :code => code, :message => message })
      end

      def check_for_json_error(response)
        return unless response["response"].key? "error"

        code = response["response"]["error"]["code"].to_i
        message = response["response"]["error"]["message"]

        log "Zoho Exception (#{code}): #{message}"

        raise Zoho::Error.new({
          :code => code,
          :message => message
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
      def xml_post(module_name, api_call, xml_document, options = {})
        url = URI(create_zoho_url('xml', module_name, api_call))

        params = required_api_parameters.merge({
          'newFormat' => '1',
          'wfTrigger' => true,
          'xmlData'   => xml_document
        }).merge!(options)

        http_response = Net::HTTP.post_form(url, params)
        response = Ox.parse(http_response.body)

        check_for_xml_error(response)

        return response
      end

      def build_xml(module_name, records)
        doc = Ox::Document.new()

        module_element = Ox::Element.new(map_custom_module_name(module_name))
        doc << module_element

        row_number = 0

        records.each do |attrs|
          row_number = row_number + 1

          row = Ox::Element.new('row')
          row[:no] = row_number
          module_element << row

          attrs.each_pair do |key, value|
            element = Ox::Element.new('FL')
            row << element

            element[:val] = map_custom_field_name(module_name, key)
            element << value.to_s
          end
        end

        Ox::dump(doc)
      end
  end
end