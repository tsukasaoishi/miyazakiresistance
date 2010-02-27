Dir.glob("#{File.join(File.dirname(__FILE__), "../initializers")}/*.rb").each{|path| require path}

module MiyazakiResistance
  VERSION = [0, 1, 6]

  def self.version
    VERSION.join * ","
  end

  autoload :Base, "miyazaki_resistance/base"
  autoload :Operation, "miyazaki_resistance/operation"
  autoload :TokyoConnection, "miyazaki_resistance/tokyo_connection"
  autoload :Enhance, "miyazaki_resistance/enhance"
  autoload :MiyazakiLogger, "miyazaki_resistance/miyazaki_logger"
end
