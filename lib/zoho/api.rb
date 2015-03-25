class Zoho::Api

  def add_record(module_name, attrs)
    x = REXML::Document.new
    element = x.add_element module_name
    row = element.add_element 'row', {'no' => '1'}
    attrs.each_pair { |k, v| add_field(row, k, v, module_name) }
    r = self.class.post(create_url(module_name, 'insertRecords'),
                        :query => {:newFormat => 1, :authtoken => @auth_token,
                                   :scope => 'crmapi', :xmlData => x, :wfTrigger => 'true'},
                        :headers => {'Content-length' => '0'})
    check_for_errors(r)
    x_r = REXML::Document.new(r.body).elements.to_a('//recorddetail')
    to_hash(x_r, module_name)[0]
  end

  def build_xml()
    doc = Ox::Document.new()
    doc << Ox::Element.new(module_name)

    doc = REXML::Document.new
    element = doc.add_element module_name
    row = element.add_element 'row', {'no' => '1'}
    attrs.each_pair { |k, v| add_field(row, k, v, module_name) }

  end
end