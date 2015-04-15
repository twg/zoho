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

  def zoho_xml_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\r\n<response uri=\"/crm/private/xml/Leads/insertRecords\"><result><message>Record(s) added successfully</message><recorddetail><FL val=\"Id\">1465372000000086057</FL><FL val=\"Created Time\">2015-04-15 07:39:49</FL><FL val=\"Modified Time\">2015-04-15 07:39:49</FL><FL val=\"Created By\"><![CDATA[Dexter Heng]]></FL><FL val=\"Modified By\"><![CDATA[Dexter Heng]]></FL></recorddetail></result></response>\r\n"
  end

  def zoho_duplicate_error_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\r\n<response uri=\"/crm/private/xml/Leads/insertRecords\"><result><message>Record(s) already exists</message><recorddetail><FL val=\"Id\">1465372000000086037</FL><FL val=\"Created Time\">2015-04-14 13:40:03</FL><FL val=\"Modified Time\">2015-04-14 13:40:03</FL><FL val=\"Created By\"><![CDATA[Dexter Heng]]></FL><FL val=\"Modified By\"><![CDATA[Dexter Heng]]></FL></recorddetail></result></response>\r\n"
  end

  def zoho_error_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\r\n<response uri=\"/crm/private/xml/Leads/insertRecords\"><error><code>4401</code><message>Unable to populate data, please check if mandatory value is entered correctly.</message></error></response>\r\n"
  end
  
  def test_insert_records
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
  end

  def test_parse_result_with_no_errors
    result = Zoho::Api.parse_result(zoho_xml_response)
    assert_equal result, true
  end

  def test_parse_result_with_error
    assert_raises Zoho::Error do
      Zoho::Api.parse_result(zoho_error_response)
    end
  end

  def test_parse_result_with_non_unique_error
    assert_raises Zoho::ErrorNonUnique do
      Zoho::Api.parse_result(zoho_duplicate_error_response)
    end
  end

end