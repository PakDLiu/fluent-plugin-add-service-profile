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
        passwordFile /etc/password/ucsPassword
      ]

    def create_driver(conf = CONFIG)
        Fluent::Test::Driver::Filter.new(Fluent::Plugin::AddServiceProfile) do
            # for testing
            def getPassword()
                return 'testPassword'
            end

            def callUcsApi(host, body)
                if body == "<aaaLogin inName=\"testDomain\\testUsername\" inPassword=\"testPassword\"></aaaLogin>" && host == "1.1.1.1"
                    return '<aaaLogin cookie="" response="yes" outCookie="1111111111/12345678-abcd-abcd-abcd-123456789000"> </aaaLogin>'
                elsif body == "<configResolveDn cookie=\"1111111111/12345678-abcd-abcd-abcd-123456789000\" dn=\"sys/chassis-4/blade-7\"></configResolveDn>" && host == "1.1.1.1"
                    return '<lsServer assignedToDn="org-root/org-T100/ls-testServiceProfile"/>'
                else
                    return ''
                end
            end
        end.configure(conf)
    end

    def filter(records)
        d = create_driver
        d.run(default_tag: "default.tag") do
            records.each do |record|
                d.feed(record)
            end
        end
        d.filtered_records
    end

    def test_configure
        d = create_driver
        assert_equal 'testDomain', d.instance.domain
        assert_equal 'testUsername', d.instance.username
    end

    def test_filter
        records = [
            { 
                "message" => "2018 Feb  9 21:07:45 GMT: %UCSM-3-LINK_DOWN: [link-down][sys/chassis-4/blade-7/fabric-A/path-3/vc-1518]",
                "host" => "1.1.1.1"
            }
        ]
        filtered_records = filter(records)
        assert_equal records[0]['message'], filtered_records[0]['message']
        assert_equal 'org-root/org-T100/ls-testServiceProfile', filtered_records[0]['serviceProfile']
    end
end