require File.expand_path('../helper', __FILE__)

describe "basic api tests" do
  # this is annoying because MiniTest doesn't support a mechanism to 
  # construct seed data. the method that is recommended runs before the 
  # test system has been setup, so we have to manually setup the API Key 
  # here (https://github.com/seattlerb/minitest/issues/61)
  def self.seed_data
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
      @update_lead_seed_id = r1['zoho_id']

      r2 = Zoho::Api.insert_records('Leads', {
        'Email'       => 'kevin.sydney@twg.ca',
        'Company'     => '<undefined>',
        'Last Name'   => 'Sydney'
      })
      @delete_lead_seed_id = r2['zoho_id']    

      r3 = Zoho::Api.insert_records('Leads', {
        'Email'       => 'henry.phillip.mccoy@twg.ca',
        'Company'     => '<undefined>',
        'Last Name'   => 'McCoy'
      })
      @convert_lead_seed_id = r3['zoho_id']

      r4 = Zoho::Api.insert_records('Leads', {
        'Email'       => 'kitty.pride@twg.ca',
        'Company'     => '<undefined>',
        'Last Name'   => 'Pride'
      })
      @insert_lead_seed_id = r4['zoho_id']      

      # when running against the live Zoho system (as opposed to VCR),
      # you have to uncomment this line out so that the tests pass
      # this is because the Zoho API is async and does not reflect its
      # state immediately
      # sleep 120
    end
  end

  def self.insert_lead_seed_id
    @insert_lead_seed_id ||= begin
      seed_data
      @insert_lead_seed_id
    end
  end

  def self.update_lead_seed_id
    @update_lead_seed_id ||= begin
      seed_data
      @update_lead_seed_id
    end
  end

  def self.delete_lead_seed_id
    @update_lead_seed_id ||= begin
      seed_data
      @delete_lead_seed_id
    end
  end

  def self.convert_lead_seed_id
    @update_lead_seed_id ||= begin
      seed_data
      @convert_lead_seed_id
    end
  end

  describe "get_record_by_id" do
    it "retrieves a single record with valid data" do
      VCR.use_cassette('get_record_by_id_valid') do
        response = Zoho::Api.get_record_by_id('Leads', self.class.update_lead_seed_id)

        assert_equal 1, response.count
      end
    end

    it "returns nil when invalid id is passed in" do
      VCR.use_cassette('get_record_by_id_invalid') do
        response = Zoho::Api.get_record_by_id('Leads', '1234')

        assert_equal nil, response
      end
    end
  end

  describe "get_records_by_ids" do
    it "retrieves multiple records with valid data" do
      VCR.use_cassette('get_records_by_ids_valid') do
        id_list = [
          self.class.update_lead_seed_id,
          self.class.insert_lead_seed_id
        ]

        response = Zoho::Api.get_records_by_ids('Leads', id_list)

        assert_equal 2, response.count
      end
    end

    it "returns nil when invalid id is passed in" do
      VCR.use_cassette('get_records_by_ids_invalid') do
        response = Zoho::Api.get_records_by_ids('Leads', ['1234', '5678'])

        assert_equal nil, response
      end
    end
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
      VCR.use_cassette('update_records_valid', :match_requests_on => [:uri, :body]) do
        result = Zoho::Api.update_records('Leads', self.class.update_lead_seed_id, { 'Email' => 'jean.grey.summers@twg.ca' })
        
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
        response = Zoho::Api.delete_records('Leads', self.class.delete_lead_seed_id)
        
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

    it "returns only the single field specified" do
      VCR.use_cassette('search_records_valid_limited') do
        response = Zoho::Api.search_records('Leads', { 'Email' => 'charles.xavier@twg.ca' }, { 'selectColumns' => 'Leads(Last Name)' })
      
        assert_equal 2, response[0].count 
        assert_equal 'Xavier', response[0]['Last Name'] 
      end
    end

    it "returns only the fields specified" do
      VCR.use_cassette('search_records_valid_limited_2') do
        response = Zoho::Api.search_records('Leads', { 'Email' => 'charles.xavier@twg.ca' }, { 'selectColumns' => 'Leads(LEADID)' })
      
        assert_equal 1, response[0].count
        assert response[0].has_key? 'LEADID' 
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
        convert_lead_response = Zoho::Api.convert_lead(self.class.convert_lead_seed_id)
        
        assert_equal Hash, convert_lead_response.class
        assert convert_lead_response.has_key?('zoho_contact_id')
        assert convert_lead_response.has_key?('zoho_account_id')
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
