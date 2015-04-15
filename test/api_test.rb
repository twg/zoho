require File.expand_path('../helper', __FILE__)

class ApiTest < Minitest::Test
  #TODO
  # add test for invalid inserts
  # add test for invalid updates
  # add test for invalid deletes


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
      assert_equal parsed_response, true
    end
  end

  def test_update_records
    VCR.use_cassette('update_records') do
      response = Zoho::Api.update_records('Leads', {'zoho_id' => 1465372000000086061, 'email' => 'organicslive@twg.ca'})
      response_message = Ox.parse(response).root.nodes[0].nodes[0].text
      parsed_response = Zoho::Api.parse_result(response)
      assert_equal parsed_response, true
      assert_equal response_message, "Record(s) updated successfully"
    end
  end

  def test_delete_records
    VCR.use_cassette('delete_records') do
      test_id = 12345
      response = Zoho::Api.delete_records('Leads', test_id)
      response_message = Ox.parse(response).root.nodes[0].nodes[1].text
      parsed_response = Zoho::Api.parse_result(response)
      assert_equal parsed_response, true
      assert_equal response_message, "Record Id(s) : #{test_id},Record(s) deleted successfully"
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
      response = Zoho::Api.post('Leads', 'insertRecords', {'xmlData' => xml_data})
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