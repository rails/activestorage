require "service/shared_service_tests"
require "httparty"

if SERVICE_CONFIGURATIONS[:s3]
  class ActiveStorage::Service::S3ServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "direct upload" do
      begin
        key  = SecureRandom.base58(24)
        data = "Something else entirely!"
        url  = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size)

        HTTParty.put(
          url,
          body: data,
          headers: { "Content-Type" => "text/plain" },
          debug_output: STDOUT
        )

        assert_equal data, @service.download(key)
      ensure
        @service.delete key
      end
    end

    test "signed URL generation" do
      assert_match /#{SERVICE_CONFIGURATIONS[:s3][:bucket]}\.s3.(\S+)?amazonaws.com.*response-content-disposition=inline.*avatar\.png/,
        @service.url(FIXTURE_KEY, expires_in: 5.minutes, disposition: :inline, filename: "avatar.png")
    end

    test "encrypt file with server_side_encryption upload option" do
      skip "server_side_encryption option not supplied " unless @service.upload_options[:server_side_encryption]

      begin
        key  = SecureRandom.base58(24)
        data = "Something else entirely!"
        response = @service.upload(key, StringIO.new(data), checksum: Digest::MD5.base64digest(data))

        assert_equal @service.upload_options[:server_side_encryption], response.server_side_encryption
      ensure
        @service.delete key
      end
    end
  end
else
  puts "Skipping S3 Service tests because no S3 configuration was supplied"
end
