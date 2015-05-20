require File.expand_path('../helper', __FILE__)
require 'faker'

describe "basic api tests" do
  # this is annoying because MiniTest doesn't support a mechanism to 
  # construct seed data. the method that is recommended runs before the 
  # test system has been setup, so we have to manually setup the API Key 
  # here (https://github.com/seattlerb/minitest/issues/61)
  def self.seed_data
    Zoho.configure do |config|
      config.api_key = '4bc37ba80b66d9e520758f84a170513d'
    end

    VCR.use_cassette('seed_data', :match_requests_on => [:uri, :body]) do
      leads = []

      leads << {
        'Email'       => 'jubilation.lee@twg.ca',
        'Company'     => '<undefined>',
        'Last Name'   => 'Lee'
      }
      leads << {
        'Email'       => 'charles.xavier@twg.ca',
        'Company'     => '<undefined>',
        'Last Name'   => 'Xavier'
      }
      leads << {
        'Email'       => 'jean.grey@twg.ca',
        'Company'     => '<undefined>',
        'Last Name'   => 'Grey'
      }
      leads << {
        'Email'       => 'kevin.sydney@twg.ca',
        'Company'     => '<undefined>',
        'Last Name'   => 'Sydney'
      }
      leads << {
        'Email'       => 'henry.phillip.mccoy@twg.ca',
        'Company'     => '<undefined>',
        'Last Name'   => 'McCoy'
      }
      leads << {
        'Email'       => 'kitty.pryde@twg.ca',
        'Company'     => '<undefined>',
        'Last Name'   => 'Pryde'
      }
      results = Zoho::Api.insert_records('Leads', leads);

      @update_lead_seed_id = results[3]
      @delete_lead_seed_id = results[4]    
      @convert_lead_seed_id = results[5]
      @insert_lead_seed_id = results[6]      

      Zoho::Api.insert_record('Contacts', {
        'Email'       => 'ororo.munroe@twg.ca',
        'Company'     => '<undefined>',
        'Last Name'   => 'Munroe',
        'First Name'  => 'Ororo'
      });

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
    @delete_lead_seed_id ||= begin
      seed_data
      @delete_lead_seed_id
    end
  end

  def self.convert_lead_seed_id
    @convert_lead_seed_id ||= begin
      seed_data
      @convert_lead_seed_id
    end
  end

  describe "get_record_by_id" do
    it "retrieves a single record with valid data" do
      VCR.use_cassette('get_record_by_id_valid') do
        response = Zoho::Api.get_record_by_id('Leads', self.class.update_lead_seed_id)

        assert_equal Hash, response.class
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

  describe "get_records" do
    it "returns nil when from_index > to_index" do
      response = Zoho::Api.get_records('Leads', 100, 50)

      assert_equal nil, response
    end

    it "returns nil when from_index < 1" do
      response = Zoho::Api.get_records('Leads', -1, 50)

      assert_equal nil, response
    end

    it "returns nil when requesting more than 200 records" do
      response = Zoho::Api.get_records('Leads', 1, 300)

      assert_equal nil, response
    end

    it "returns multple results" do
      VCR.use_cassette('get_records') do
        response = Zoho::Api.get_records('Leads', 1, 50)

        refute_equal 1, response
      end
    end
  end

  describe "insert_records" do
    it "inserts records with valid data" do
      VCR.use_cassette('insert_record_valid', :match_requests_on => [:uri, :body]) do
        response = Zoho::Api.insert_record('Leads', {
          'Email'       => 'scott.summers@twg.ca',
          'Company'     => '<undefined>',
          'Last Name'   => 'Summers'
        })

        assert_equal String, response.class
      end
    end

    it "raises non unique error on duplicate insert" do
      # invoke the seed_data generation method
      self.class.insert_lead_seed_id

      error = assert_raises Zoho::ErrorNonUnique do
        VCR.use_cassette('insert_record_duplicate', :match_requests_on => [:uri, :body]) do
          response = Zoho::Api.insert_record('Leads', {
            'Email'       => 'kitty.pryde@twg.ca',
            'Company'     => '<undefined>',
            'Last Name'   => 'Pryde'
          })
        end
      end
    end

    it "raises an error with invalid insert data" do
      error = assert_raises Zoho::Error do
        VCR.use_cassette('insert_record_invalid', :match_requests_on => [:uri, :body]) do
          Zoho::Api.insert_record('Leads', {})
        end
      end

      assert_equal 4891, error.code
    end

    it "inserts multiple valid records" do
      VCR.use_cassette('insert_records_valid') do
        leads = (1..200).map do |x|
          {
            'Email' => Faker::Internet.email,
            'Company' => Faker::Company.name,
            'Last Name' => Faker::Name.last_name
          }
        end 

        response = Zoho::Api.insert_records('Leads', leads)

        assert_equal 200, response.count
        assert response.all? do |item|
          item.class == String
        end
      end
    end
  end

  describe "update_records" do
    it "updates a record with valid data" do
      VCR.use_cassette('update_record_valid', :match_requests_on => [:uri, :body]) do
        result = Zoho::Api.update_record('Leads', self.class.update_lead_seed_id, { 'Email' => 'jean.grey.summers@twg.ca' })
        
        assert_equal true, result
      end
    end

    it "raises an error with invalid update data" do
      error = assert_raises Zoho::Error do
        VCR.use_cassette('update_record_invalid', :match_requests_on => [:uri, :body]) do
          Zoho::Api.update_record('Leads', 'bogus', { 'Email' => 'test@email.com'}) 
        end
      end

      assert_equal 4500, error.code
    end

    it "raises an error with invalid update data" do
      VCR.use_cassette('update_record_invalid_2', :match_requests_on => [:uri, :body]) do
        leads = []

        leads << { 'ID' => '1418626000000186588', 'Organics Account id_ID' => 'test@email.com' }
        leads << { 'ID' => self.class.update_lead_seed_id, 'Email' => 'jean.grey.summers@twg.ca' }

        results = Zoho::Api.update_records('Leads', leads)

        assert 2, results.count
        assert results.all? do |item|
          item.is_a? Zoho::Error
        end 
      end
    end    

    it "bulk updates records" do
      VCR.use_cassette('update_records_valid') do
        leads = (1..200).map do |x|
          {
            'Email' => Faker::Internet.email,
            'Company' => Faker::Company.name,
            'Last Name' => Faker::Name.last_name
          }
        end 

        response = Zoho::Api.insert_records('Leads', leads)

        response.each_pair do |k,v|
          leads[k.to_i - 1]['Id'] = v
        end

        response = Zoho::Api.update_records('Leads', leads)

        assert_equal 200, response.count
        assert response.all? do |r|
          r == true
        end
      end
    end
  end

  describe "delete_record" do
    it "deletes record with valid data" do
      VCR.use_cassette('delete_record_valid') do
        response = Zoho::Api.delete_record('Leads', self.class.delete_lead_seed_id)
        
        assert_equal true, response
      end
    end

    it "raises an error with invalid delete data" do
      error = assert_raises Zoho::Error do
        VCR.use_cassette('delete_record_invalid') do
          Zoho::Api.delete_record('Leads', 'bogus123')
        end
      end

      assert_equal 4600, error.code
    end  
  end

  describe "search_records_async" do
    it "finds the right record with valid search terms" do
      VCR.use_cassette('search_records_async_valid') do
        response = Zoho::Api.search_records_async('Leads', { 'Email' => 'charles.xavier@twg.ca' })
        assert_equal 1, response.count
      end
    end

    it "returns only the single field specified" do
      VCR.use_cassette('search_records_async_valid_limited') do
        response = Zoho::Api.search_records_async('Leads', { 'Email' => 'charles.xavier@twg.ca' }, { 'selectColumns' => 'Leads(Last Name)' })
      
        assert_equal 2, response[0].count 
        assert_equal 'Xavier', response[0]['Last Name'] 
      end
    end

    it "returns only the fields specified" do
      VCR.use_cassette('search_records_async_valid_limited_2') do
        response = Zoho::Api.search_records_async('Leads', { 'Email' => 'charles.xavier@twg.ca' }, { 'selectColumns' => 'Leads(LEADID)' })
      
        assert_equal 1, response[0].count
        assert response[0].has_key? 'LEADID' 
      end
    end

    it "finds nothing with bad query" do
      VCR.use_cassette('search_records_async_no_records') do
        response = Zoho::Api.search_records_async('Leads', { 'Email' => 'bruce.wayne@twg.ca' })
        assert_equal nil, response
      end
    end

    it "throws error with malformed query" do
      error = assert_raises Zoho::Error do
        VCR.use_cassette('search_records_async_malformed') do
          Zoho::Api.search_records_async('Leads', { 'Em|ail' => 'charles.xavier@twg.ca' })
        end
      end

      assert_equal 4832, error.code
    end
  end

  describe "search_records_sync" do
    it "finds the record immediately" do
      VCR.use_cassette('search_records_sync_immediate') do
        Zoho::Api.insert_record('Leads', {
          'Email'       => 'robert.drake@twg.ca',
          'Company'     => '<undefined>',
          'Last Name'   => 'Drake'
        });

        result = Zoho::Api.search_records_sync('Leads', 'Last Name', '=', 'Drake')

        assert_equal 'Drake', result[0]['Last Name']
      end
    end
  end

  describe "get_users" do
    it "retrieves a user by name" do
      VCR.use_cassette('get_users_valid') do
        users = Zoho::Api.get_users('name', 'mister+user')

        assert_equal 1, users.count
        assert_equal 'mister+user', users[0]["content"]
      end
    end

    it "retrieves multiple users when no criteria specified" do
      # this test assumes that the Zoho instance the auth token
      # points to has multiple users
      VCR.use_cassette('get_users_multiple') do
        users = Zoho::Api.get_users()

        refute_equal 1, users.count
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

  describe "module mapping" do
    it "correctly maps Customers to Contacts" do
      Zoho.configure do |config|
        config.custom_modules_map = {
          'Customers' => 'Contacts'
        }
      end

      VCR.use_cassette('map_customers_to_contacts') do
        response = Zoho::Api.search_records_async('Customers', { 'Last Name' => 'Munroe' })

        assert_equal 1, response.count
      end
    end
  end

  describe "field mapping" do
    before do
      Zoho.configure do |config|
        config.custom_fields_map = {
          'Leads' => {
            'FooBar' => 'Last Name'
          }
        }
      end
    end

    after do
      Zoho.configure do |config|
        config.custom_fields_map = {}
      end 
    end

    it "correctly maps FooBar to Last Name on insertion" do
      VCR.use_cassette('map_fields_upload') do
        response = Zoho::Api.insert_record('Leads', {
          'Email'       => 'emma.frost@twg.ca',
          'Company'     => '<undefined>',
          'FooBar'      => 'Frost'
        })

        assert_equal String, response.class
      end    
    end

    it "correctly maps Last Name to FooBar on retrieval" do
      VCR.use_cassette('map_fields_download') do
        response = Zoho::Api.search_records_async('Leads', { 'Email' => 'charles.xavier@twg.ca' })

        assert_equal 1, response.count
        assert_equal 'Xavier', response[0]['FooBar']
      end     
    end
  end

  describe "Logging" do
    it "logs appropriately when the logger is set" do
      Zoho.configure do |config|
        s = StringIO.new

        config.logger = Logger.new(s)

        VCR.use_cassette('get_users_valid') do
          Zoho::Api.get_users('name', 'mister+user')
        end

        assert s.string.include? 'get_users field=name, value=mister+user, filter_by=all_users'
      end
    end
  end
end
