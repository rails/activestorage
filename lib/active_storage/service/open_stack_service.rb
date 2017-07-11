require "fog/openstack"

class ActiveStorage::Service::OpenStackService < ActiveStorage::Service
  attr_reader :client, :container

  def initialize(container:, openstack_username:, openstack_api_key:,
    openstack_region:, openstack_auth_url:, openstack_project_id:, openstack_temp_url_key:, connection_options:)
    @client = Fog::Storage::OpenStack.new(
      openstack_auth_url: openstack_auth_url,
      openstack_username: openstack_username,
      openstack_api_key: openstack_api_key,
      openstack_project_id: openstack_project_id,
      openstack_region: openstack_region,
      openstack_temp_url_key: openstack_temp_url_key,
      connection_options: connection_options
    )
    @container = @client.directories.get(container)
  end

  def upload(key, io, checksum: nil)
    instrument :upload, key, checksum: checksum do
      # FIXME: Max file size is 5GB. If support for files
      # larger than that is desired, we have to
      # segment the upload.
      file = container.files.create(key: key, body: io, etag: checksum)
      file.reload
      puts file.inspect
      puts "Base64 #{Digest::MD5.base64digest(file.body)}"
      puts "Hex #{Digest::MD5.hexdigest(file.body)}"
      puts "The checksum #{checksum}"
      puts "The file checksum #{file.etag}"

      if checksum.present? && Digest::MD5.base64digest(file.body) != checksum
        raise ActiveStorage::IntegrityError
        file.destroy
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
        file_for(key).body
      end
    end
  end

  def delete(key)
    instrument :delete, key do
      file_for(key).try(:destroy)
    end
  end

  def exist?(key)
    instrument :exist, key do |payload|
      answer = file_for(key).present?
      payload[:exist] = answer
      answer
    end
  end

  def url(key, expires_in:, disposition:, filename:)
    instrument :url, key do |payload|
      generated_url = file_for(key).url(expires_in) + "&" +
        { "response-content-disposition" => "#{disposition}; filename=\"#{filename}\"" }.to_query

      payload[:url] = generated_url

      generated_url
    end
  end

  def url_for_direct_upload(key, expires_in:, content_type:, content_length:)
    raise NotImplementedError
  end

  private
    def file_for(key)
      container.files.get(key)
    end

    def stream(key, options = {}, &block)
      file_for(key) do | data, remaining, content_length |
        yield data
      end
    end
end
