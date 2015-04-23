require File.expand_path('../helper', __FILE__)

describe "insert_records" do
  it "inserts records with valid data" do
    VCR.use_cassette('insert_record_valid', :match_requests_on => [:uri, :body]) do
      response = Zoho::Api.insert_records('Leads', {
        'Email'       => 'abel.n.willin@twg.ca',
        'Company'     => 'Abel N Willin Enterprises',
        'Last Name'   => 'Willin'
      })

      assert_equal Hash, response.class
      assert response.has_key?('zoho_id')
    end
  end

  it "raises non unique error on duplicate insert" do
    error = assert_raises Zoho::ErrorNonUnique do
      VCR.use_cassette('insert_record_duplicate', :match_requests_on => [:uri, :body]) do
        Zoho::Api.insert_records('Leads', {
          'Email'       => 'abel.n.willin@twg.ca',
          'Company'     => 'Abel N Willin Enterprises',
          'Last Name'   => 'Willin'
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
      result = Zoho::Api.update_records('Leads', 1465372000000094013, { 'Email' => 'organicslive@twg.ca' })
      
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
      response = Zoho::Api.delete_records('Leads', 12345)
      
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
      response = Zoho::Api.search_records('Leads', { 'Email' => 'abel.n.willin@twg.ca' })
      assert_nil nil, response
    end
  end

  it "returns only the parts specified" do
    VCR.use_cassette('search_records_valid_limited') do
      response = Zoho::Api.search_records('Leads', { 'Email' => 'abel.n.willin@twg.ca' }, { 'selectColumns' => 'Leads(Last Name)' })
    
      assert_equal 2, response[0].count 
      assert_equal 'Willin', response[0]['Last Name'] 
    end
  end

  it "finds nothing with bad query" do
    VCR.use_cassette('search_records_no_records') do
      response = Zoho::Api.search_records('Leads', { 'Email' => 'tony.stark@twg.ca' })
      assert_equal nil, response
    end
  end

  it "throws error with malformed query" do
    error = assert_raises Zoho::Error do
      VCR.use_cassette('search_records_malformed') do
        Zoho::Api.search_records('Leads', { 'Em|ail' => 'tony.stark@twg.ca' })
      end
    end

    assert_equal 4832, error.code
  end  
end

describe "search_users" do
  it "retrieves a user by name" do
    VCR.use_cassette('search_users_valid') do
      users = Zoho::Api.search_users('name', 'blah blah')

      assert_equal 1, users.count
      assert_equal 'blah blah', users[0]["content"]
    end
  end

  it "retrieves all users" do
    VCR.use_cassette('get_users') do
      users = Zoho::Api.search_users()

      assert_equal 2, users.count
    end
  end
end
