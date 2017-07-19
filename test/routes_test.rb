require "test_helper"

require "active_storage/disk_controller"
require "active_storage/direct_uploads_controller"
require "active_storage/verified_key_with_expiration"

class RoutingTest < ActionController::TestCase
  setup do
    @blob = create_blob
    @filename = @blob.filename
    @encoded_key = ActiveStorage::VerifiedKeyWithExpiration.encode(@blob.key, expires_in: 5.minutes)
    @routes = Routes
  end

  test 'that downloading action is properly routed' do
    assert_recognizes(
      {
        controller: 'active_storage/disk',
        action: 'show',
        encoded_key: @encoded_key,
        filename: @filename.base ,
        format: @filename.extension,
      },
      {
        path: "/rails/active_storage/disk/#{@encoded_key}/#{@filename}",
        method: :get
      }
    )
  end

  test 'that downloading action is properly routed when providing attachment disposition' do
    assert_recognizes(
      {
        controller: 'active_storage/disk',
        action: 'show',
        encoded_key: @encoded_key,
        filename: @filename.base ,
        format: @filename.extension,
        disposition: "attachment"
      },
      "/rails/active_storage/disk/#{@encoded_key}/#{@filename}", { disposition: "attachment" }
    )
  end

  test 'POSTING to direct_uploads will call the create action on DirectUploadsController ' do
    assert_recognizes(
      {
        controller: 'active_storage/direct_uploads',
        action: 'create'
      },
      {
        path: "/rails/active_storage/direct_uploads",
        method: :post
      }
    )
  end
end
