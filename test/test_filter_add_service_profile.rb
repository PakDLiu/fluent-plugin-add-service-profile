require 'fluent/test'
require 'fluent/test/driver/filter'
require 'fluent/plugin/filter_add_service_profile'

class AddServiceProfile < Test::Unit::TestCase
    def setup
        Fluent::Test.setup
    end

    CONFIG = %[
        @type add_service_profile
        domain testDomain
        username testUsername
        ucsIp 1.1.1.1
      ]

    def create_driver(conf = CONFIG)
        Fluent::Test::Driver::Filter.new(Fluent::Plugin::AddServiceProfile) do
            # for testing
            def getPassword()
                return 'testPassword'
            end

            def callUcsApi(body)
                if body == "<aaaLogin inName=\"testDomain\\testUsername\" inPassword=\"testPassword\"></aaaLogin>"
                    return '<aaaLogin cookie="" response="yes" outCookie="1111111111/12345678-abcd-abcd-abcd-123456789000"> </aaaLogin>'
                elsif body == "<configResolveDn cookie=\"1111111111/12345678-abcd-abcd-abcd-123456789000\" dn=\"sys/chassis-4/blade-7\"></configResolveDn>"                              
                    return '<lsServer assignedToDn="org-root/org-T100/ls-testServiceProfile"/>'
                else
                    return ''
                end
            end
        end.configure(conf)
    end

    def filter(messages)
        d = create_driver
        d.run(default_tag: "default.tag") do
            messages.each do |message|
                d.feed(message)
            end
        end
        d.filtered_records
    end

    def test_configure
        d = create_driver
        assert_equal 'testDomain', d.instance.domain
        assert_equal 'testUsername', d.instance.username
        assert_equal '1.1.1.1', d.instance.ucsIp
    end

    def test_filter
        messages = [
            { "message" => "2018 Feb  9 21:07:45 GMT: %UCSM-3-LINK_DOWN: [link-down][sys/chassis-4/blade-7/fabric-A/path-3/vc-1518]"}
        ]
        filtered_records = filter(messages)
        assert_equal messages[0]['message'], filtered_records[0]['message']
        assert_equal 'org-root/org-T100/ls-testServiceProfile', filtered_records[0]['serviceProfile']
    end
end