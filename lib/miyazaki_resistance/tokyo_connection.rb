require 'yaml'
module MiyazakiResistance
  module TokyoConnection
    def self.included(base)
      base.extend ClassMethods
      base.__send__(:include, InstanceMethods)
    end

    module ClassMethods
      attr_accessor :connection_pool
      attr_accessor :all_columns
      attr_accessor :timeout_time

      DEFAULT = {
        :timeout => 60,
        :config => "miyazakiresistance.yml",
        :port => 1978,
        :role => :readonly
      }

      def server_config(env, file = DEFAULT[:config])
        env = env.to_s
        conf = YAML.load_file(file)
        if (config = conf[env]).nil?
          logger_fatal "specified environment(#{env}) is not found in conig file(#{file})"
          return
        end

        class_variable_set("@@logger", Logger.new(config["log_file"])) if config["log_file"]

        config["set_server"].each do |work|
          set_server work["server"], work["port"], work["role"]
        end
      rescue Errno::ENOENT => e
        logger_fatal "config file is not found : #{file}"
      end

      def set_server(host, port = DEFAULT[:port], role = DEFAULT[:role])
        self.connection_pool ||= {:read => [], :write => nil, :standby => nil}
        rdb = TokyoTyrant::RDBTBL.new
        logger_info "set server host : #{host} port : #{port} role : #{role}"

        unless rdb.open(host.to_s, port)
          logger_fatal "TokyoTyrantConnectError host : #{host} port : #{port} role : #{role}"
          raise TokyoTyrantConnectError
        end

        self.connection_pool[:read] << rdb
        self.connection_pool[:write] = rdb if role.to_sym == :write
        self.connection_pool[:standby] = rdb if role.to_sym == :standby
      end

      def set_timeout(seconds)
        self.timeout_time = seconds.to_i
      end

      def set_column(name, type, index = :no_index)
        self.all_columns ||= {}
        name = name.to_s
        self.__send__(:attr_accessor, name)
        self.all_columns.update(name => type)
      end

      def read_connection
        check_pool
        self.connection_pool[:read].sort_by{rand}.first
      end

      def write_connection
        self.connection_pool[:write]
      end

      def remove_pool(rdb)
        self.connection_pool[:read].delete_if{|pool| pool == rdb}

        host, port = rdb.host, rdb.port
        new_rdb = TokyoTyrant::RDBTBL.new
        if new_rdb.open(host, port)
          self.connection_pool[:read] << new_rdb
          self.connection_pool[:write] = new_rdb if rdb == self.connection_pool[:write]
        else
          logger_fatal "remove pool : host #{host} port : #{port}"
          check_pool
          fail_over if rdb == self.connection_pool[:write]
        end
        rdb.close
      end

      def kaeru_timeout(&block)
        ret = nil
        thread = Thread.new{ret = yield}
        raise TimeoutError, "tokyo tyrant server response error" unless thread.join(self.timeout_time || DEFAULT[:timeout])
        ret
      end

      private

      def all_connections
        [self.connection_pool[:read], self.connection_pool[:write], self.connection_pool[:standby]].flatten.compact.uniq
      end

      def check_pool
        return if self.connection_pool[:read] && !self.connection_pool[:read].empty?
        logger_fatal "AllTimeoutORConnectionPoolEmpty"
        raise AllTimeoutORConnectionPoolEmpty
      end

      def fail_over
        unless self.connection_pool[:standby]
          logger_fatal "MasterDropError"
          raise MasterDropError
        end

        logger_fatal "master server failover"
        self.connection_pool[:write] = self.connection_pool[:standby]
        self.connection_pool[:standby] = nil
      end
    end

    module InstanceMethods
      def read_connection
        self.class.read_connection
      end

      def write_connection
        self.class.write_connection
      end

      def remove_pool(rdb)
        self.class.remove_pool(rdb)
      end

      def kaeru_timeout(&block)
        self.class.kaeru_timeout(&block)
      end
    end
  end
end
