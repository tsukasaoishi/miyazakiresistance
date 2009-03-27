module MiyazakiResistance
  module TokyoConnection
    def self.included(base)
      base.extend ClassMethods
      base.__send__(:include, InstanceMethods)
    end

    module ClassMethods
      attr_accessor :connection_pool
      attr_accessor :all_columns
      attr_accessor :all_indexes
      attr_accessor :timeout_time

      DEFAULT_TIMEOUT = 60

      def set_server(host, port, target = :readonly)
        logger.debug "set_server host : #{host} port : #{port} target : #{target}"

        self.connection_pool ||= {:read => [], :write => nil, :standby => nil}
        rdb = TokyoTyrant::RDBTBL.new
        unless rdb.open(host.to_s, port)
          logger.error "TokyoTyrantConnectError host : #{host} port : #{port} target : #{target}"
          raise TokyoTyrantConnectError
        end

        self.connection_pool[:read] << rdb
        self.connection_pool[:write] = rdb if target == :write
        self.connection_pool[:standby] = rdb if target == :standby
      end

      def set_timeout(seconds)
        self.timeout_time = seconds.to_i
      end

      def set_column(name, type, index = :no_index)
        self.all_indexes ||= []
        self.all_columns ||= {}
        name = name.to_s
        self.__send__(:attr_accessor, name)
        self.all_columns.update(name => type)

        set_index(name, type) if index == :index
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
        check_pool
        fail_over if rdb == self.connection_pool[:write]
      end

      def kaeru_timeout(&block)
        ret = nil
        thread = Thread.new{ret = yield}
        raise TimeoutError unless thread.join(self.timeout_time || DEFAULT_TIMEOUT)
        ret
      end

      private

      def all_connections
        [self.connection_pool[:read], self.connection_pool[:write], self.connection_pool[:standby]].flatten.compact.uniq
      end

      def check_pool
        return if self.connection_pool[:read] && !self.connection_pool[:read].empty?
        logger.error "AllTimeoutORConnectionPoolEmpty"
        raise AllTimeoutORConnectionPoolEmpty
      end

      def fail_over
        unless self.connection_pool[:standby]
          logger.error "MasterDropError"
          raise MasterDropError
        end

        logger.info "master server failover"
        self.connection_pool[:write] = self.connection_pool[:standby]
        self.connection_pool[:standby] = nil
      end

      def set_index(name, type)
        index_type = case type
          when :integer, :datetime, :date
            TokyoTyrant::RDBTBL::ITDECIMAL
          when :string
            TokyoTyrant::RDBTBL::ITLEXICAL
          end

        self.all_indexes << name
        all_connections.each do |con|
          begin
            con.setindex(name, index_type)
            con.setindex(name, TokyoTyrant::RDBTBL::ITOPT)
          rescue TimeoutError
            remove_pool(con)
            retry
          end
        end
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
