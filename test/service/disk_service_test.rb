require "tmpdir"
require "service/shared_service_tests"

class ActiveStorage::Service::DiskServiceTest < ActiveSupport::TestCase
  SERVICE = ActiveStorage::Service.configure(:test, test: { service: "Disk", root: File.join(Dir.tmpdir, "active_storage") })

  include ActiveStorage::Service::SharedServiceTests
end
