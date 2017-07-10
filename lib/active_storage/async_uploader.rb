require "concurrent/promise"

class ActiveStorage::AsyncUploader
  class << self
    def result(uploaders)
      promises = uploaders.map(&:promise)
      Concurrent::Promise.zip(*promises).value!
    end
  end

  attr_reader :promise

  def initialize(service, key, checksum: nil)
    @data = ""
    @eof = false
    @promise = Concurrent::Promise.execute do
      until eof? do; end
      service.upload key, StringIO.new(@data), checksum: checksum
    end
  end

  def eof?
    @eof
  end

  def write(chunk)
    @data << chunk
    @eof = false
  end

  def close
    @eof = true
  end
end
