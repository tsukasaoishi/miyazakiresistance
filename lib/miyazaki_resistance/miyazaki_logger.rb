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
        @@logger ||= Logger.new("miyazakiresistance.log")
      end

      def logger=(target)
        @@logger = target
      end
    end

    module InstanceMethods
      def logger
        self.class.logger
      end
    end
  end
end
