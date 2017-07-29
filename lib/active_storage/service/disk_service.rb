require "fileutils"
require "pathname"
require "digest/md5"
require "active_support/core_ext/numeric/bytes"

# Wraps a local disk path as a Active Storage service. See `ActiveStorage::Service` for the generic API
# documentation that applies to all services.
class ActiveStorage::Service::DiskService < ActiveStorage::Service
  attr_reader :root

  def initialize(root:)
    @root = root
  end

  def upload(key, io, checksum: nil)
    instrument :upload, key, checksum: checksum do
      IO.copy_stream(io, make_path_for(key))
      ensure_integrity_of(key, checksum) if checksum
    end
  end

  def download(key)
    if block_given?
      instrument :streaming_download, key do
        File.open(path_for(key), "rb") do |file|
          while data = file.read(64.kilobytes)
            yield data
          end
        end
      end
    else
      instrument :download, key do
        File.binread path_for(key)
      end
    end
  end

  def delete(key)
    instrument :delete, key do
      begin
        File.delete path_for(key)
      rescue Errno::ENOENT
        # Ignore files already deleted
      end
    end
  end

  def exist?(key)
    instrument :exist, key do |payload|
      answer = File.exist? path_for(key)
      payload[:exist] = answer
      answer
    end
  end

  def url(key, expires_in:, disposition:, filename:, content_type:)
    instrument :url, key do |payload|
      verified_key_with_expiration = ActiveStorage.verifier.generate(key, expires_in: expires_in, purpose: :blob_key)

      generated_url =
        if defined?(Rails.application)
          Rails.application.routes.url_helpers.rails_disk_service_path \
            verified_key_with_expiration,
            disposition: disposition, filename: filename, content_type: content_type
        else
          "/rails/active_storage/disk/#{verified_key_with_expiration}/#{filename}?disposition=#{disposition}&content_type=#{content_type}"
        end

      payload[:url] = generated_url

      generated_url
    end
  end

  def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:)
    instrument :url, key do |payload|
      verified_token_with_expiration = ActiveStorage.verifier.generate(
        {
          key: key,
          content_type: content_type,
          content_length: content_length,
          checksum: checksum
        },
        expires_in: expires_in,
        purpose: :blob_token
      )

      generated_url =
        if defined?(Rails.application)
          Rails.application.routes.url_helpers.update_rails_disk_service_path verified_token_with_expiration
        else
          "/rails/active_storage/disk/#{verified_token_with_expiration}"
        end

      payload[:url] = generated_url

      generated_url
    end
  end

  def headers_for_direct_upload(key, content_type:, **)
    { "Content-Type" => content_type }
  end

  private
    def path_for(key)
      File.join root, folder_for(key), key
    end

    def folder_for(key)
      [ key[0..1], key[2..3] ].join("/")
    end

    def make_path_for(key)
      path_for(key).tap { |path| FileUtils.mkdir_p File.dirname(path) }
    end

    def ensure_integrity_of(key, checksum)
      unless Digest::MD5.file(path_for(key)).base64digest == checksum
        delete key
        raise ActiveStorage::IntegrityError
      end
    end
end
