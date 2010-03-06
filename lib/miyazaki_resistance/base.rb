module MiyazakiResistance
  class Base
    attr_accessor :id

    def initialize(args = nil)
      self.id = nil
      set_args(args || {})      
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

      def method_missing(name, *arguments, &block)
        if match = finder_attribute_names(name)
          finder = match[:finder]
          conditions = match[:cols].map{|col| "#{col} = ?"}.join(" ")

          self.class_eval %Q|
            def self.#{name}(*args)
              options = args.last.is_a?(::Hash) ? pop : {}
              options.update(:conditions => ["#{conditions}", args].flatten)
              self.find(:#{finder}, options)
            end
          |

          __send__(name, *arguments)
        else
          super
        end
      end
    end

    private

    def self.type_upcase(type)
      case type
      when :number, :datetime, :date
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
          type = (target == "id" ? :number : self.all_columns[target])
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
            type = :number
          elsif OPERATIONS.keys.include?(item)
            raise QueryError if col.nil? || type.nil?
            work = type
            work = :number if DATE_TYPE.include?(work)
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

    def self.finder_attribute_names(name)
      ret = {:finder => :first, :cols => nil}
      if name.to_s =~ /^find_(all_by|by)_([_a-zA-Z]\w*)$/
        ret[:finder] = :all if $1 == "all_by"
        if cols = $2
          cols = cols.split("_and_")
          all_cols = self.all_columns.keys
          ret[:cols] = cols  if cols.all?{|col| all_cols.include?(col)}
        end
      end
      (ret[:cols].nil? || ret[:cols].empty?) ? nil : ret
    end
  end
end
