require "service/shared_service_tests"
require "net/http"
require "uri"

if SERVICE_CONFIGURATIONS[:gcs]
  class ActiveStorage::Service::GCSServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:gcs, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "direct upload" do
      begin
        key = SecureRandom.base58(24)
        data = "Something else entirely!"
        direct_upload_url = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size)

        write_to_url(data, direct_upload_url)

        assert_equal data, @service.download(key)
      ensure
        @service.delete key
      end
    end

    test "signed URL generation" do
      travel_to Time.now do
        url = SERVICE.bucket.signed_url(FIXTURE_KEY, expires: 120) +
          "&response-content-disposition=inline%3B+filename%3D%22test.txt%22"

        assert_equal url, @service.url(FIXTURE_KEY, expires_in: 2.minutes, disposition: :inline, filename: "test.txt")
      end
    end

    def write_to_url(data, url)
      url = URI(url)

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Put.new(url)
      request["content-type"] = "text/plain"
      request["origin"] = "http://localhost:3000"
      request["cache-control"] = "no-cache"
      request.body = data

      response = http.request(request)
      puts response.read_body
    end
  end
else
  puts "Skipping GCS Service tests because no GCS configuration was supplied"
end
