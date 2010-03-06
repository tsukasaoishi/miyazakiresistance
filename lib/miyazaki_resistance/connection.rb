require 'tokyotyrant'
require 'timeout'
require 'yaml'

module MiyazakiResistance
  class Base
    @@connection_manager = {}

    class <<self
      %w|server_config server timeout remove_pool|.each do |method|
        class_eval %Q|
          def #{method}(*args)
            connection_or_create.#{method}(*args)
          end
        |
      end
      alias :set_server :server
      alias :set_timeout :timeout

      %w|read write|.each do |role|
        class_eval %Q|
          def #{role}_connection
            con = connection
            con ? con.#{role}_connection : nil
          end
        |
      end

      def connection
        @@connection_manager[self]
      end

      def connection_or_create
        @@connection_manager[self] ||= MR::Connection.new
      end

      def kaeru_timeout(&block)
        con = connection
        con.kaeru_timeout(&block)
      end
    end

    def read_connection
      self.class.read_connection
    end

    def write_connection
      self.class.write_connection
    end

    def remove_pool(con)
      self.class.remove_pool(con)
    end

    def kaeru_timeout(&block)
      self.class.kaeru_timeout(&block)
    end
  end

  class Connection
    DEFAULT = {:timeout => 5, :config => "miyazakiresistance.yml", :port => 1978, :role => :readonly}

    attr_accessor :connection_pool
    attr_accessor :timeout_time

    def server_config(env, file = DEFAULT[:config])
      conf = YAML.load_file(file)
      if config = conf[env.to_s]
        config["set_server"].each do |work|
          server(work["server"], work["port"], work["role"])
        end
      else
        MR::MiyazakiLogger.fatal "specified environment(#{env}) is not found in conig file(#{file})"
      end
    rescue Errno::ENOENT => e
      MR::MiyazakiLogger.fatal "config file is not found : #{file}"
    end

    def server(host, port = DEFAULT[:port], role = DEFAULT[:role])
      self.connection_pool ||= {:read => [], :write => nil, :standby => nil}
      rdb = TokyoTyrant::RDBTBL.new
      MR::MiyazakiLogger.info "set server host : #{host} port : #{port} role : #{role}"

      rdb.set_server(host.to_s, port)

      if role.to_sym == :standby
        self.connection_pool[:standby] = rdb
      else
        self.connection_pool[:read] << rdb
        self.connection_pool[:write] = rdb if role.to_sym == :write
      end
    end

    def timeout(seconds)
      self.timeout_time = seconds.to_i
    end

    def connection(con)
      unless con.open?
        unless con.open
          MR::MiyazakiLogger.fatal "TokyoTyrantConnectError host : #{con.host} port : #{con.port}"
          raise MiyazakiResistance::TokyoTyrantConnectError
        end
      end
      con
    end

    def read_connection
      check_pool
      connection(self.connection_pool[:read].sort_by{rand}.first)
    end

    def write_connection
      connection(self.connection_pool[:write])
    end

    def remove_pool(rdb)
      self.connection_pool[:read].delete_if{|pool| pool == rdb}

      host, port = rdb.host, rdb.port
      new_rdb = TokyoTyrant::RDBTBL.new
      if new_rdb.open(host, port)
        self.connection_pool[:read] << new_rdb
        self.connection_pool[:write] = new_rdb if rdb == self.connection_pool[:write]
      else
        MR::MiyazakiLogger.fatal "remove pool : host #{host} port : #{port}"
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
      MR::MiyazakiLogger.fatal "AllTimeoutORConnectionPoolEmpty"
      raise MiyazakiResistance::AllTimeoutORConnectionPoolEmpty
    end

    def fail_over
      unless self.connection_pool[:standby]
        MR::MiyazakiLogger.fatal "MasterDropError"
        raise MiyazakiResistance::MasterDropError
      end

      MR::MiyazakiLogger.fatal "master server failover"
      self.connection_pool[:write] = self.connection_pool[:standby]
      self.connection_pool[:read] << self.connection_pool[:standby]
      self.connection_pool[:standby] = nil
    end
  end
end
