module Cursory
  def self.version
    return "1.0.#{ENV['SNAP_PIPELINE_COUNTER']}" if ENV['SNAP_PIPELINE_COUNTER']
    "1.0.0"
  end
  VERSION = version
end
