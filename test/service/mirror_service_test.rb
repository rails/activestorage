require "tmpdir"
require "service/shared_service_tests"

class ActiveStorage::Service::MirrorServiceTest < ActiveSupport::TestCase
  mirror_config = (1..3).map do |i|
    [ "mirror_#{i}",
      service: "Disk",
      root: File.join(Dir.tmpdir, "active_storage_mirror_#{i}") ]
  end.to_h

  config = mirror_config.merge \
    mirror:   { service: "Mirror", primary: 'primary', mirrors: mirror_config.keys },
    primary:  { service: "Disk", root: File.join(Dir.tmpdir, "active_storage") }

  SERVICE = ActiveStorage::Service.configure :mirror, config

  include ActiveStorage::Service::SharedServiceTests

  test "uploading to all services" do
    begin
      data = "Something else entirely!"
      key  = upload(data, to: @service)

      assert_equal data, SERVICE.primary.download(key)
      SERVICE.mirrors.each do |mirror|
        assert_equal data, mirror.download(key)
      end
    ensure
      @service.delete key
    end
  end

  test "downloading from primary service" do
    data = "Something else entirely!"
    key  = upload(data, to: SERVICE.primary)

    assert_equal data, @service.download(key)
  end

  test "deleting from all services" do
    @service.delete FIXTURE_KEY
    assert_not SERVICE.primary.exist?(FIXTURE_KEY)
    SERVICE.mirrors.each do |mirror|
      assert_not mirror.exist?(FIXTURE_KEY)
    end
  end

  test "URL generation in primary service" do
    travel_to Time.now do
      assert_equal SERVICE.primary.url(FIXTURE_KEY, expires_in: 2.minutes, disposition: :inline, filename: "test.txt"),
        @service.url(FIXTURE_KEY, expires_in: 2.minutes, disposition: :inline, filename: "test.txt")
    end
  end

  private
    def upload(data, to:)
      SecureRandom.base58(24).tap do |key|
        io = StringIO.new(data).tap(&:read)
        @service.upload key, io, checksum: Digest::MD5.base64digest(data)
        assert io.eof?
      end
    end
end
