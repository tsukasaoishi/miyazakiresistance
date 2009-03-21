$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'tokyotyrant'
require 'timeout'

module MiyazakiResistance
  VERSION = '0.0.1'

  class NewRecordError < StandardError; end
  class QueryError < StandardError; end
  class AllTimeoutORConnectionPoolEmpty < StandardError; end

  module Connection
    def self.included(base)
      base.extend ClassMethods
      base.__send__(:include, InstanceMethods)
    end

    module ClassMethods
      attr_accessor :connection_pool
      attr_accessor :all_columns
      attr_accessor :timeout_time

      def host_and_port(host, port, target = :write)
        self.connection_pool ||= {:read => [], :write => []}
        rdb = TokyoTyrant::RDBTBL.new
        return unless rdb.open(host, port)
        self.connection_pool[:read] << rdb
        self.connection_pool[:write] << rdb if target == :write
      end

      def set_timeout(seconds)
        self.timeout_time = seconds.to_i
      end

      def set_column(name, type)
        name = name.to_s
        self.__send__(:attr_accessor, name)
        self.all_columns ||= {}
        self.all_columns.update(name => type)
      end

      def connection(target = :read)
        check_pool(target)
        self.connection_pool[target].sort_by{rand}.first
      end

      def remove_pool(rdb)
        [:read, :write].each do |target|
          self.connection_pool[target].delete_if{|pool| pool == rdb}
          check_pool(target)
        end
      end

      def kaeru_timeout(&block)
        ret = nil
        thread = Thread.new{ret = yield}
        raise TimeoutError unless thread.join(self.timeout_time)
        ret
      end

      private

      def check_pool(target)
        raise AllTimeoutORConnectionPoolEmpty if self.connection_pool[target].empty?
      end
    end

    module InstanceMethods
      def connection(target = :read)
        self.class.connection(target)
      end

      def remove_pool(rdb)
        self.class.remove_pool(rdb)
      end

      def kaeru_timeout(&block)
        self.class.kaeru_timeout(&block)
      end
    end
  end

  class Base
    include Connection

    OPERATIONS = {
      "=" => {:string => TokyoTyrant::RDBQRY::QCSTREQ, :integer => TokyoTyrant::RDBQRY::QCNUMEQ},
      "include" => {:string => TokyoTyrant::RDBQRY::QCSTRINC},
      "begin" => {:string => TokyoTyrant::RDBQRY::QCSTRBW},
      "end" => {:string => TokyoTyrant::RDBQRY::QCSTREW},
      "allinclude" => {:string => TokyoTyrant::RDBQRY::QCSTRAND},
      "anyinclude" => {:string => TokyoTyrant::RDBQRY::QCSTROR},
      "in" => {:string => TokyoTyrant::RDBQRY::QCSTROREQ, :integer => TokyoTyrant::RDBQRY::QCNUMOREQ},
      "=~" => {:string => TokyoTyrant::RDBQRY::QCSTRRX},
      ">" => {:integer => TokyoTyrant::RDBQRY::QCNUMGT},
      ">=" => {:integer => TokyoTyrant::RDBQRY::QCNUMGE},
      "<" => {:integer => TokyoTyrant::RDBQRY::QCNUMLT},
      "<=" => {:integer => TokyoTyrant::RDBQRY::QCNUMLE},
      "between" => {:integer => TokyoTyrant::RDBQRY::QCNUMBT}
    }
    DATE_TYPE = [:datetime, :date]

    attr_accessor :id

    def initialize(args={})
      self.id = nil
      args.each do |key, value|
        case self.class.all_columns[key.to_s]
        when :integer
          value = value.to_i
        when :string
          value = value.to_s
        when :datetime
          value = Time.at(value.to_i) unless value.is_a?(Time)
        when :date
          unless value.is_a?(Date)
            time = Time.at(value.to_i)
            value = Date.new(time.year, time.month, time.day)
          end
        end
        
        self.__send__("#{key}=", value)
      end
    end

    def save
      time_column_check
      con = connection(:write)
      self.id = kaeru_timeout{con.genuid.to_i} if new_record?
      kaeru_timeout{con.put(self.id, raw_attributes)}
    rescue TimeoutError
      remove_pool(con)
      retry
    end


    def update_attributes(args)
      raise NewRecordError if new_record?
      attributes = args
      save
    end

    def destroy
      raise NewRecordError if new_record?
      con = connection(:write)
      kaeru_timeout{con.out(self.id)}
    rescue TimeoutError
      remove_pool(con)
      retry
    end

    def attributes
      hash = {}
      self.class.all_columns.keys.each{|key| hash.update(key => self.__send__(key))}
      hash
    end

    def attributes=(args)
      args.each {|key, value| self.__send__("#{key}=", value)}
    end

    def new_record?
      self.id.nil?
    end

    class << self
      def find(first, args={})
        case first.class.name
        when "Fixnum"
          find_by_id(first)
        when "Array"
          find_by_ids(first)
        when "Symbol"
          find_by_query(first, args)
        else
          raise ArgumentError
        end
      end

      def find_by_query(mode, args={})
        con = connection
        query = TokyoTyrant::RDBQRY.new(con)

        limit = (mode == :first ? 1 : args[:limit])
        query = make_limit(query, limit, args[:offset])
        query = make_order(query, args[:order])
        query = make_conditions(query, args[:conditions])
        
        ids = kaeru_timeout{query.search}
        ret = find_by_ids(ids)
        ret = ret.first if limit.to_i == 1
        ret
      rescue TimeoutError
        remove_pool(con)
        retry
      end

      def find_by_id(target)
        find_by_ids([target])
      end

      def count(args = {})
        con = connection
        if args.empty?
          kaeru_timeout{con.rnum}
        else
          query = TokyoTyrant::RDBQRY.new(con)
          query = make_conditions(query, args[:conditions])
          kaeru_timeout{query.search}.size
        end
      rescue TimeoutError
        remove_pool(con)
        retry
      end

      def create(args)
        inst = self.new(args)
        inst.save
        inst
      end
    end

    private

    def raw_attributes
      hash = {}
      self.class.all_columns.each do |col, type|
        value = self.__send__(col)
        value = self.class.convert_date_to_i(value, type)
        hash.update(col.to_s => value)
      end
      hash
    end

    def time_column_check
      time_columns = ["updated"]
      time_columns << "created" if new_record?
      time_columns.each do |col|
        %w|at on|.each do |type|
          if self.class.all_columns.keys.include?("#{col}_#{type}")
            now = Time.now
            now = Date.new(now.year, now.month, now.day) if type == "on"
            self.__send__("#{col}_#{type}=", now) if self.__send__("#{col}_#{type}").nil? || col == "updated"
          end
        end
      end
    end

    def self.type_upcase(type)
      case type
      when :integer, :datetime, :date
        "NUM"
      when :string
        "STR"
      end
    end

    def self.find_by_ids(targets)
      targets.map do |key|
        begin
          con = connection
          data = kaeru_timeout{con.get(key)}
          inst = self.new(data)
          inst.id = key.to_i
          inst
        rescue TimeoutError
          remove_pool(con)
          retry
        end
      end
    end

    def self.make_limit(query, limit, offset)
      query.setlimit(limit, offset) if limit
      query
    end

    def self.make_order(query, order)
      if order
        target, order_type = order.split
        if self.all_columns.keys.include?(target)
          type = self.all_columns[target]
          order_type ||= "asc"
          eval(%Q|query.setorder(target, TokyoTyrant::RDBQRY::QO#{type_upcase(type)}#{order_type.upcase})|)
        end
      end
      query
    end

    def self.make_conditions(query, conditions)
      if conditions
        cond = conditions.first
        param = conditions[1..-1]

        col, ope, exp, type = nil, nil, nil, nil
        cond.split.each do |item|
          if self.all_columns.keys.include?(item)
            col = item
            type = self.all_columns[item]
          elsif item == "id"
            col = ""
            type = :integer
          elsif OPERATIONS.keys.include?(item)
            raise QueryError if col.nil? || type.nil?
            work = type
            work = :integer if DATE_TYPE.include?(work)
            ope = OPERATIONS[item][work]
          else
            raise QueryError if col.nil? || type.nil? || ope.nil?
            exp = (item == "?" ? param.shift : item)
            exp = convert_date_to_i(exp, type)
          end

          if col && type && ope && exp
            query.addcond(col, ope, exp.to_s)
            col, ope, exp, type = nil, nil, nil, nil
          end
        end
      end
      query
    end

    def self.convert_date_to_i(value, type)
      case type
      when :datetime
        value.to_i
      when :date
        Time.local(value.year, value.month, value.day).to_i
      else
        value
      end
    end
  end
end
