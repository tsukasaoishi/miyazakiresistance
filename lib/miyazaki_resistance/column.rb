module MiyazakiResistance
  class Base
    class << self
      attr_accessor :all_columns

      def column(name, type, index = :no_index)
        self.all_columns ||= {}
        name = name.to_s
        self.__send__(:attr_accessor, name)
        type = :number if type.to_s == "integer"
        self.all_columns.update(name => type)
      end
      alias :set_column :column

      def plastic_data(value, type)
        ret = case type
        when :datetime
          value ? value.to_i : nil
        when :date
          value ? Time.local(value.year, value.month, value.day).to_i : nil
        else
          value
        end
        ret.to_s
      end
    end

    def attributes
      self.class.all_columns.keys.inject({}) {|hash, key| hash.merge(key => self.__send__(key))}
    end

    def attributes=(args)
      args.each {|key, value| self.__send__("#{key}=", value)}
    end

    private

    def raw_attributes
      hash = {}
      self.class.all_columns.each do |col, type|
        next unless value = self.__send__(col)
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

    def set_args(args)
      args.each do |key, value|
        if key.is_a?(String) && key.empty?
          key, = :id
          value = value.to_i if value
        else
          case self.class.all_columns[key.to_s]
          when :number
            value = (value =~ /\./) ? value.to_f : value.to_i if value
          when :string
            value = value.to_s if value
          when :datetime
            value = Time.at(value.to_i) if value && !value.is_a?(Time)
          when :date
            if value && !value.is_a?(Date)
              time = Time.at(value.to_i)
              value = Date.new(time.year, time.month, time.day)
            end
          else
            next
          end
        end
        
        self.__send__("#{key}=", value)
      end
    end
  end
end
