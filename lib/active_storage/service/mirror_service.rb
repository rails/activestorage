require "active_support/core_ext/module/delegation"
require "active_storage/async_uploader"
require "concurrent/promise"

class ActiveStorage::Service::MirrorService < ActiveStorage::Service
  CHUNK_SIZE = 1024
  attr_reader :primary, :mirrors

  delegate :download, :exist?, :url, to: :primary

  # Stitch together from named services.
  def self.build(primary:, mirrors:, configurator:, **options) #:nodoc:
    new \
      primary: configurator.build(primary),
      mirrors: mirrors.collect { |name| configurator.build name }
  end

  def initialize(primary:, mirrors:)
    @primary, @mirrors = primary, mirrors
  end

  def upload(key, io, checksum: nil)
    uploaders = each_service.collect do |service|
      ActiveStorage::AsyncUploader.new(service, key, checksum: checksum)
    end
    io.rewind
    while chunk = io.read(CHUNK_SIZE)
      uploaders.each { |uploader| uploader.write(chunk) }
    end
    ActiveStorage::AsyncUploader.result(uploaders.each(&:close))
  end

  def delete(key)
    perform_async_across_services :delete, key
  end

  private
    def each_service(&block)
      [ primary, *mirrors ].each(&block)
    end

    def perform_async_across_services(method, *args)
      promises = each_service.collect do |service|
        Concurrent::Promise.execute { service.public_send method, *args }
      end
      Concurrent::Promise.zip(*promises).value!
    end
end
