require File.expand_path('../helper', __FILE__)

class ApiTest < Minitest::Test

  def base_url
    "https://crm.zoho.com/crm/private/xml"
  end

  def sample_xml
    "\n<Leads>\n  <row no=\"1\">\n    <FL val=\"Name\">Tester</FL>\n  </row>\n</Leads>\n"
  end

  def empty_xml
    "\n<Leads>\n  <row no=\"1\"/>\n</Leads>\n"
  end

  def valid_insert_params
    {
      'email'       => 'organics_test@organics.com',
      'company'     => 'Organics Live',
      'last name'   => 'Owner'
    }
  end
  
  def test_insert_records
    VCR.use_cassette('insert_records') do
      response = Zoho::Api.insert_records('Leads', valid_insert_params)
      parsed_response = Zoho::Api.parse_result(response)
      assert_equal parsed_response , true
    end
  end

  def test_build_xml
    xml = Zoho::Api.build_xml('Leads', {})
    assert_equal xml, empty_xml 

    xml = Zoho::Api.build_xml('Leads', {'name' => 'Tester'})
    assert_equal xml, sample_xml
  end

  def test_create_url
    url = Zoho::Api.create_url('Leads', 'insertRecords')
    assert_equal url, "#{base_url}/Leads/insertRecords"
  end

  def test_post
    xml_data = Zoho::Api.build_xml('Leads', valid_insert_params)

    VCR.use_cassette('insert_records') do
      response = Zoho::Api.post('Leads', 'insertRecords', xml_data)
      assert_equal response.class, String
    end
  end

  def test_parse_result_with_no_errors
    path = File.expand_path(File.dirname(__FILE__)) + "/fixtures/insert_success.xml"
    result = Zoho::Api.parse_result(File.read(path))
    assert_equal result, true
  end

  def test_parse_result_with_error
    path = File.expand_path(File.dirname(__FILE__)) + "/fixtures/insert_error.xml"
    assert_raises Zoho::Error do
      Zoho::Api.parse_result(File.read(path))
    end
  end

  def test_parse_result_with_non_unique_error
    path = File.expand_path(File.dirname(__FILE__)) + "/fixtures/insert_duplicate.xml"
    assert_raises Zoho::ErrorNonUnique do
      Zoho::Api.parse_result(File.read(path))
    end
  end

end