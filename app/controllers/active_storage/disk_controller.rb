# Serves files stored with the disk service in the same way that the cloud services do.
# This means using expiring, signed URLs that are meant for immediate access, not permanent linking.
# Always go through the BlobsController, or your own authenticated controller, rather than directly
# to the service url.
class ActiveStorage::DiskController < ActionController::Base
  def show
    if key = decode_verified_key
      send_data disk_service.download(key),
        filename: params[:filename], disposition: disposition_param, content_type: params[:content_type]
    else
      head :not_found
    end
  end

  def update
    if token = decode_verified_token
      if acceptable_content?(token)
        disk_service.upload token[:key], request.body, checksum: token[:checksum]
      else
        head :unprocessable_entity
      end
    else
      head :not_found
    end
  rescue ActiveStorage::IntegrityError
    head :unprocessable_entity
  end

  private
    def disk_service
      ActiveStorage::Blob.service
    end


    def decode_verified_key
      ActiveStorage.verifier.verified(params[:encoded_key], purpose: :blob_key)
    end

    def disposition_param
      params[:disposition].presence_in(%w( inline attachment )) || "inline"
    end


    def decode_verified_token
      ActiveStorage.verifier.verified(params[:encoded_token], purpose: :blob_token)
    end

    # FIXME: Validate Content-Length when we're using integration tests. Controller tests don't
    # populate the header properly when a request body is provided.
    def acceptable_content?(token)
      token[:content_type] == request.content_type
    end
end
