Dir.glob("#{File.join(File.dirname(__FILE__), "../initializers")}/*.rb").each{|path| require path}

module MiyazakiResistance
  VERSION = [0, 1, 6]

  def self.version
    VERSION * "."
  end
end
MR = MiyazakiResistance

require "miyazaki_resistance/column"
require "miyazaki_resistance/operation"
require "miyazaki_resistance/connection"
require "miyazaki_resistance/base"
require "miyazaki_resistance/miyazaki_logger"
require "miyazaki_resistance/error"
