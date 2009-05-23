module MiyazakiResistance
  module MiyazakiLogger
    def self.included(base)
      base.class_eval do
        @@logger = nil
      end
      base.extend ClassMethods
      base.__send__(:include, InstanceMethods)
    end

    module ClassMethods
      def logger
        class_variable_get("@@logger") || (logger = Logger.new("miyazakiresistance.log"))
      end

      def logger=(target)
        class_variable_set("@@logger", target)
      end

      %w|fatal error warn info debug|.each do|level|
        self.class_eval %Q|
          def logger_#{level}(str)
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
    end

    module InstanceMethods
      def logger
        self.class.logger
      end

      %w|fatal error warn info debug|.each do|level|
        self.class_eval %Q|
          def logger_#{level}(str)
            self.class.logger_#{level}g(str)
          end
        |
      end
    end
  end
end
