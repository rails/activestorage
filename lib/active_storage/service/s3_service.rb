require "aws-sdk"
require "active_support/core_ext/numeric/bytes"

class ActiveStorage::Service::S3Service < ActiveStorage::Service
  attr_reader :client, :bucket

  def initialize(access_key_id:, secret_access_key:, region:, bucket:, endpoint: nil)
    @client = if endpoint
      Aws::S3::Resource.new(
        access_key_id:     access_key_id,
        secret_access_key: secret_access_key,
        region:            region,
        endpoint:          endpoint
      )
    else
      Aws::S3::Resource.new(
        access_key_id:     access_key_id,
        secret_access_key: secret_access_key,
        region:            region
      )
    end

    @bucket = @client.bucket(bucket)
  end

  def upload(key, io, checksum: nil)
    instrument :upload, key, checksum: checksum do
      begin
        object_for(key).put(body: io, content_md5: checksum)
      rescue Aws::S3::Errors::BadDigest
        raise ActiveStorage::IntegrityError
      end
    end
  end

  def download(key)
    if block_given?
      instrument :streaming_download, key do
        stream(key, &block)
      end
    else
      instrument :download, key do
        object_for(key).get.body.read.force_encoding(Encoding::BINARY)
      end
    end
  end

  def delete(key)
    instrument :delete, key do
      object_for(key).delete
    end
  end

  def exist?(key)
    instrument :exist, key do |payload|
      answer = object_for(key).exists?
      payload[:exist] = answer
      answer
    end
  end

  def url(key, expires_in:, disposition:, filename:)
    instrument :url, key do |payload|
      safe_filename = ActiveSupport::Inflector.transliterate(filename.to_s)
      generated_url = object_for(key).presigned_url :get, expires_in: expires_in,
        response_content_disposition: "#{disposition}; filename=\"#{safe_filename}\""

      payload[:url] = generated_url

      generated_url
    end
  end

  def url_for_direct_upload(key, expires_in:, content_type:, content_length:)
    instrument :url, key do |payload|
      generated_url = object_for(key).presigned_url :put, expires_in: expires_in,
        content_type: content_type, content_length: content_length

      payload[:url] = generated_url

      generated_url
    end
  end

  private
    def object_for(key)
      bucket.object(key)
    end

    # Reads the object for the given key in chunks, yielding each to the block.
    def stream(key, options = {}, &block)
      object = object_for(key)

      chunk_size = 5.megabytes
      offset = 0

      while offset < object.content_length
        yield object.read(options.merge(range: "bytes=#{offset}-#{offset + chunk_size - 1}"))
        offset += chunk_size
      end
    end
end
