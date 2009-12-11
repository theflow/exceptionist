require File.dirname(__FILE__) + '/test_helper'

context "Parse Hoptoad XML" do
  test 'should parse a exception' do
    hash = Exceptionist::Occurrence.parse_xml(File.read('fixtures/exception.xml'))

    assert_equal 'http://example.com', hash[:url]
    assert_equal 'users', hash[:controller_name]
    assert_equal nil, hash[:action_name]
    assert_equal 'RuntimeError', hash[:exception_class]
    assert_equal 'RuntimeError: I have made a huge mistake', hash[:exception_message]
    assert_equal ["/testapp/app/models/user.rb:53:in `public'",
                  "/testapp/app/controllers/users_controller.rb:14:in `index'"], hash[:exception_backtrace]
    assert_equal 'production', hash[:environment]

    assert_equal({ "SERVER_NAME"=>"example.org", "HTTP_USER_AGENT"=>"Mozilla" }, hash[:cgi_data])
    assert_equal({}, hash[:session])
    assert_equal({}, hash[:parameters])
  end

  test 'should parse a minimal exception' do
    assert_nothing_raised do
      Exceptionist::Occurrence.parse_xml(File.read('fixtures/minimal_exception.xml'))
    end
  end

  test 'should parse a full exception' do
    assert_nothing_raised do
      Exceptionist::Occurrence.parse_xml(File.read('fixtures/full_exception.xml'))
    end
  end
end
