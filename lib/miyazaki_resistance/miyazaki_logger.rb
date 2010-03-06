require 'logger'

module MiyazakiResistance
  class MiyazakiLogger
    @@logger = nil

    def initialize(file)
      @file = file
    end

    class << self
      def logger
        @@logger || (logger = Logger.new(default_log_file_path))
      end

      def logger=(target)
        @@logger = target
      end

      %w|fatal error warn info debug|.each do|level|
        self.class_eval %Q|
          def #{level}(str)
            put_log(str, "#{level}")
          end
        |
      end

      private

      def put_log(str, level)
        logger.__send__(level, log_msg(str))
      end

      def log_msg(str)
        "[#{Time.now.strftime("%Y/%m/%d %H:%M:%S")}] #{str}"
      end

      def default_log_file_path
        File.directory?("log") ? "log/miyazakiresistance.log" : "miyazakiresistance.log"
      end
    end
  end
end
