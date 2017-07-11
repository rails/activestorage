require "service/shared_service_tests"

if SERVICE_CONFIGURATIONS[:openstack]
  class ActiveStorage::Service::OpenStackServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:openstack, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "signed URL generation" do
      travel_to Time.now do
        url = SERVICE.container.files.get_https_url(FIXTURE_KEY, 120) +
          "&response-content-disposition=inline%3B+filename%3D%22test.txt%22"

        assert_equal url, @service.url(FIXTURE_KEY, expires_in: 2.minutes, disposition: :inline, filename: "test.txt")
      end
    end
  end
else
  puts "Skipping OpenStack Service tests because no OpenStack configuration was supplied"
end
