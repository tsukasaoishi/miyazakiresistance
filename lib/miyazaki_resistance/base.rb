module MiyazakiResistance
  class Base
    attr_accessor :id

    def initialize(args = nil)
      args ||= {}
      self.id = nil
      args.each do |key, value|
        if key.is_a?(String) && key.empty?
          key = :id
          value = value.to_i
        else
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
        end
        
        self.__send__("#{key}=", value)
      end
    end

    def save
      time_column_check
      con = write_connection
      self.id = kaeru_timeout{con.genuid.to_i} if new_record?
      kaeru_timeout {con.put(self.id, raw_attributes)}
      self
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
      con = write_connection
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
        con = read_connection
        query = TokyoTyrant::RDBQRY.new(con)

        limit = (mode == :first ? 1 : args[:limit])
        query = make_limit(query, limit, args[:offset])
        query = make_order(query, args[:order])
        query = make_conditions(query, args[:conditions])
        
        results = kaeru_timeout{query.searchget}.map{|r| self.new(r)}
        limit.to_i == 1 ? results.first : results
      rescue TimeoutError
        remove_pool(con)
        retry
      end

      def find_by_id(target)
        find_by_ids([target]).first
      end

      def find_and_update(first, args={})
        list = self.find(first, args)
        list = [list] unless list.is_a?(Array)
        list.each {|inst| yield(inst) and inst.save}
      end

      def first(args = {})
        find(:first, args)
      end

      def count(args = {})
        con = read_connection
        if args.empty?
          kaeru_timeout{con.rnum}
        else
          query = TokyoTyrant::RDBQRY.new(con)
          query = make_conditions(query, args[:conditions])
          query.respond_to?(:searchcount) ? kaeru_timeout{query.searchcount} : kaeru_timeout{query.search.count}
        end
      rescue TimeoutError
        remove_pool(con)
        retry
      end

      def delete_all(args = [])
        con = write_connection
        if args.empty?
          con.vanish
        else
          query = TokyoTyrant::RDBQRY.new(con)
          query = make_conditions(query, args)
          kaeru_timeout{query.searchout}
        end
      rescue TimeoutError
        remove_pool(con)
        retry
      end

      def create(args)
        self.new(args).save
      end
    end

    private

    def raw_attributes
      hash = {}
      self.class.all_columns.each do |col, type|
        value = self.__send__(col)
        value = self.class.plastic_data(value, type)
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
      ret = Hash[*targets.map{|t| [t, nil]}.flatten]
      con = read_connection
      kaeru_timeout{con.mget(ret)}
      
      ret.map do |r|
        inst = self.new(r.last)
        inst.id = r.first.to_i
        inst
      end
    rescue TimeoutError
      remove_pool(con)
      retry
    end

    def self.make_limit(query, limit, offset)
      query.setlimit(limit, offset) if limit
      query
    end

    def self.make_order(query, order)
      if order
        target, order_type = order.split
        if target == "id" || self.all_columns.keys.include?(target)
          type = (target == "id" ? :integer : self.all_columns[target])
          target = "" if target == "id"
          order_type ||= "asc"
          eval(%Q|query.setorder(target, TokyoTyrant::RDBQRY::QO#{type_upcase(type)}#{order_type.upcase})|)
        end
      end
      query
    end

    def self.make_conditions(query, conditions)
      if conditions
        add_cond_list = []
        cond = conditions.first
        param = conditions[1..-1]

        col, ope, exp, type = nil, nil, nil, nil
        not_flag = false
        cond.split.each do |item|
          next if %w|AND and|.include?(item)

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
            if not_flag
              raise QueryError unless NOT_OPERATIONS.include?(item)
              ope = TokyoTyrant::RDBQRY::QCNEGATE | ope
              not_flag = false
            end
          elsif %w|NOT not|.include?(item)
            not_flag = true
          else
            raise QueryError if col.nil? || type.nil? || ope.nil?
            exp = (item == "?" ? param.shift : item)
            if exp.is_a?(Array)
              exp = exp.map{|e| plastic_data(e, type)}.join(" ")
            else
              exp = plastic_data(exp, type)
            end
          end

          if col && type && ope && exp
            add_cond_list << [col, ope, exp]
            col, ope, exp, type = nil, nil, nil, nil
            not_flag = false
          end
        end
        add_cond_list.reverse.each{|acl| query.addcond(*acl)}
      end
      query
    end

    def self.plastic_data(value, type)
      ret = case type
      when :datetime
        value.to_i
      when :date
        Time.local(value.year, value.month, value.day).to_i
      else
        value
      end
      ret.to_s
    end
  end
end
