require File.expand_path('../helper', __FILE__)

describe "basic api tests" do
  @@update_lead_seed_id = nil
  @@delete_lead_seed_id = nil
  @@convert_lead_seed_id = nil

  # this is annoying because MiniTest doesn't support a mechanism to 
  # construct seed data. the method that is recommended runs before the 
  # test system has been setup, so we have to manually setup the API Key 
  # here
  Zoho.configure do |config|
    config.api_key = 'ccabd7ff5cb3f1ad9b0bb27a17a20626'
  end

  VCR.use_cassette('seed_data', :match_requests_on => [:uri, :body]) do
    Zoho::Api.insert_records('Leads', {
      'Email'       => 'jubilation.lee@twg.ca',
      'Company'     => '<undefined>',
      'Last Name'   => 'Lee'
    });

    Zoho::Api.insert_records('Leads', {
      'Email'       => 'charles.xavier@twg.ca',
      'Company'     => '<undefined>',
      'Last Name'   => 'Xavier'
    })

    r1 = Zoho::Api.insert_records('Leads', {
      'Email'       => 'jean.grey@twg.ca',
      'Company'     => '<undefined>',
      'Last Name'   => 'Grey'
    })
    @@update_lead_seed_id = r1['zoho_id']

    r2 = Zoho::Api.insert_records('Leads', {
      'Email'       => 'kevin.sydney@twg.ca',
      'Company'     => '<undefined>',
      'Last Name'   => 'Sydney'
    })
    @@delete_lead_seed_id = r2['zoho_id']    

    r3 = Zoho::Api.insert_records('Leads', {
      'Email'       => 'henry.phillip.mccoy@twg.ca',
      'Company'     => '<undefined>',
      'Last Name'   => 'McCoy'
    })
    @@convert_lead_seed_id = r3['zoho_id']

    # when running against the live Zoho system (as opposed to VCR),
    # you have to uncomment this line out so that the tests pass
    # this is because the Zoho API is async and does not reflect its
    # state immediately
    # sleep 120
  end

  describe "insert_records" do
    it "inserts records with valid data" do
      VCR.use_cassette('insert_record_valid', :match_requests_on => [:uri, :body]) do
        response = Zoho::Api.insert_records('Leads', {
          'Email'       => 'scott.summers@twg.ca',
          'Company'     => '<undefined>',
          'Last Name'   => 'Summers'
        })

        assert_equal Hash, response.class
        assert response.has_key?('zoho_id')
      end
    end

    it "raises non unique error on duplicate insert" do
      error = assert_raises Zoho::ErrorNonUnique do
        VCR.use_cassette('insert_record_duplicate', :match_requests_on => [:uri, :body]) do
          Zoho::Api.insert_records('Leads', {
            'Email'       => 'jubilation.lee@twg.ca',
            'Company'     => '<undefined>',
            'Last Name'   => 'Lee'
          });
        end
      end
    end

    it "raises an error with invalid insert data" do
      error = assert_raises Zoho::Error do
        VCR.use_cassette('insert_record_invalid', :match_requests_on => [:uri, :body]) do
          Zoho::Api.insert_records('Leads', {})
        end
      end

      assert_equal 4401, error.code
    end
  end

  describe "update_records" do
    it "updates records with valid data" do
    l = Logger.new(STDOUT)
    l.info @@update_lead_seed_id
          
      VCR.use_cassette('update_records_valid', :match_requests_on => [:uri, :body]) do
        result = Zoho::Api.update_records('Leads', @@update_lead_seed_id, { 'Email' => 'jean.grey.summers@twg.ca' })
        
        assert_equal true, result
      end
    end

    it "raises an error with invalid update data" do
      error = assert_raises Zoho::Error do
        VCR.use_cassette('update_records_invalid', :match_requests_on => [:uri, :body]) do
          Zoho::Api.update_records('Leads', 'bogus', { 'Email' => 'test@email.com'}) 
        end
      end

      assert_equal 4600, error.code
    end
  end

  describe "delete_records" do
    it "deletes record with valid data" do
      VCR.use_cassette('delete_records_valid') do
        response = Zoho::Api.delete_records('Leads', @@delete_lead_seed_id)
        
        assert_equal true, response
      end
    end

    it "raises an error with invalid delete data" do
      error = assert_raises Zoho::Error do
        VCR.use_cassette('delete_records_invalid') do
          Zoho::Api.delete_records('Leads', 'bogus123')
        end
      end

      assert_equal 4600, error.code
    end  
  end

  describe "search_records" do
    it "finds the right record with valid search terms" do
      VCR.use_cassette('search_records_valid') do
        response = Zoho::Api.search_records('Leads', { 'Email' => 'charles.xavier@twg.ca' })
        assert_equal 1, response.count
      end
    end

    it "returns only the parts specified" do
      VCR.use_cassette('search_records_valid_limited') do
        response = Zoho::Api.search_records('Leads', { 'Email' => 'charles.xavier@twg.ca' }, { 'selectColumns' => 'Leads(Last Name)' })
      
        assert_equal 2, response[0].count 
        assert_equal 'Xavier', response[0]['Last Name'] 
      end
    end

    it "finds nothing with bad query" do
      VCR.use_cassette('search_records_no_records') do
        response = Zoho::Api.search_records('Leads', { 'Email' => 'bruce.wayne@twg.ca' })
        assert_equal nil, response
      end
    end

    it "throws error with malformed query" do
      error = assert_raises Zoho::Error do
        VCR.use_cassette('search_records_malformed') do
          Zoho::Api.search_records('Leads', { 'Em|ail' => 'charles.xavier@twg.ca' })
        end
      end

      assert_equal 4832, error.code
    end  
  end

  describe "get_users" do
    it "retrieves a user by name" do
      VCR.use_cassette('get_users_valid') do
        users = Zoho::Api.get_users('name', 'blah blah')

        assert_equal 1, users.count
        assert_equal 'blah blah', users[0]["content"]
      end
    end

    it "retrieves all users" do
      VCR.use_cassette('get_users_multiple') do
        users = Zoho::Api.get_users()

        assert_equal 2, users.count
      end
    end
  end

  describe "convert_lead" do
    it "converts a lead to a contact" do
      VCR.use_cassette('convert_lead_valid') do
        convert_lead_response = Zoho::Api.convert_lead(@@convert_lead_seed_id)
        
        assert_equal Hash, convert_lead_response.class
        assert convert_lead_response.has_key?('zoho_id')
      end
    end

    it "errors out with invalid input" do
      error = assert_raises Zoho::Error do
        VCR.use_cassette('convert_lead_invalid') do
          Zoho::Api.convert_lead('blahblahblah')
        end
      end

      assert_equal 4600, error.code    
    end
  end
end

# describe "organicslive fragments" do
#   class Account
#     attr_accessor :email
#     attr_accessor :first_name
#     attr_accessor :last_name
#     attr_accessor :primary_phone
#     attr_accessor :delivery_address_line1
#     attr_accessor :delivery_city
#     attr_accessor :delivery_state_province
#     attr_accessor :delivery_postal_zip
#     attr_accessor :delivery_country
#     attr_accessor :registration_complete
#     attr_accessor :zone_name
#     attr_accessor :zoho_id
#   end

#   it "creates new lead when registration is not complete" do
#     VCR.use_cassette('organicslive_sign_up_insert') do
#       account = Account.new
#       account.email = 'steve.rogers@twg.ca'
#       account.last_name = 'Rogers'
#       account.first_name = 'Steve'
#       account.primary_phone = '555-555-2278'
#       account.delivery_address_line1 = '1 Yonge St'
#       account.delivery_city = 'Toronto'
#       account.delivery_state_province = 'ON'
#       account.delivery_postal_zip = 'M5V 1E1'
#       account.delivery_country = 'Canada'
#       account.registration_complete = false
#       account.zone_name = 'M5V'

#       sync_with_zoho_crm account
#     end    
#   end

#   it "updates an existing lead when registration is not complete" do
#     VCR.use_cassette('organicslive_sign_up_update') do
#       response = Zoho::Api.insert_records('Leads', {
#         'Email'       => 'tony.stark@twg.ca',
#         'Company'     => '<undefined>',
#         'Last Name'   => 'Stark'
#       })

#       wait_for_zoho_to_sync

#       account = Account.new
#       account.email = 'tony.stark@twg.ca'
#       account.last_name = 'Stark'
#       account.first_name = 'Tony'
#       account.primary_phone = '555-555-2278'
#       account.delivery_address_line1 = '1 Yonge St'
#       account.delivery_city = 'Toronto'
#       account.delivery_state_province = 'ON'
#       account.delivery_postal_zip = 'M5V 1E1'
#       account.delivery_country = 'Canada'
#       account.registration_complete = false
#       account.zone_name = 'M5V'
#       account.zoho_id = response['zoho_id']

#       sync_with_zoho_crm account
#     end    
#   end

#   it "reassigns lead ownership when the FSA changes" do
#     VCR.use_cassette('organicslive_sign_up_update_fsa_change') do
#       account = Account.new
#       account.email = 'bruce.banner@twg.ca'
#       account.last_name = 'Banner'
#       account.first_name = 'Bruce'
#       account.primary_phone = '555-555-2278'
#       account.delivery_address_line1 = '1 Yonge St'
#       account.delivery_city = 'Toronto'
#       account.delivery_state_province = 'ON'
#       account.delivery_postal_zip = 'M5V 1E1'
#       account.delivery_country = 'Canada'
#       account.registration_complete = false
#       account.zone_name = 'M5V'

#       sync_with_zoho_crm account

#       wait_for_zoho_to_sync

#       account.delivery_postal_zip = 'L3T 3J2'
#       account.zone_name = 'L3T'

#       sync_with_zoho_crm account
#     end
#   end

#   it "does not reassign lead ownership when the FSA changes to something that does not exist" do
#     VCR.use_cassette('organicslive_sign_up_update_bad_fsa_change') do
#       account = Account.new
#       account.email = 'natalia.romanova@twg.ca'
#       account.last_name = 'Romanova'
#       account.first_name = 'Natalia'
#       account.primary_phone = '555-555-2278'
#       account.delivery_address_line1 = '1 Yonge St'
#       account.delivery_city = 'Toronto'
#       account.delivery_state_province = 'ON'
#       account.delivery_postal_zip = 'M5V 1E1'
#       account.delivery_country = 'Canada'
#       account.registration_complete = false
#       account.zone_name = 'M5V'

#       sync_with_zoho_crm account

#       wait_for_zoho_to_sync

#       account.delivery_postal_zip = 'L6L'
#       account.zone_name = 'L6L'

#       sync_with_zoho_crm account
#     end
#   end

#   it "removes lead and creates contact when the registration is completed" do
#     VCR.use_cassette('organicslive_sign_up_complete') do
#       account = Account.new
#       account.email = 'clint.barton@twg.ca'
#       account.last_name = 'Barton'
#       account.first_name = 'Clint'
#       account.primary_phone = '555-555-2278'
#       account.delivery_address_line1 = '1 Yonge St'
#       account.delivery_city = 'Toronto'
#       account.delivery_state_province = 'ON'
#       account.delivery_postal_zip = 'M5V 1E1'
#       account.delivery_country = 'Canada'
#       account.registration_complete = false
#       account.zone_name = 'M5V'

#       sync_with_zoho_crm account

#       wait_for_zoho_to_sync

#       account.registration_complete = true

#       sync_with_zoho_crm account
#     end
#   end

#   it "updates contacts" do
#     VCR.use_cassette('organicslive_updates_contact') do
#       account = Account.new
#       account.email = 'thor.odinson@twg.ca'
#       account.last_name = 'Odinson'
#       account.first_name = 'Thor'
#       account.primary_phone = '555-555-2278'
#       account.delivery_address_line1 = '1 Yonge St'
#       account.delivery_city = 'Toronto'
#       account.delivery_state_province = 'ON'
#       account.delivery_postal_zip = 'M5V 1E1'
#       account.delivery_country = 'Canada'
#       account.registration_complete = true
#       account.zone_name = 'M5V'

#       sync_with_zoho_crm account

#       account.primary_phone = '555-555-8467'

#       sync_with_zoho_crm account
#     end
#   end    
# end
