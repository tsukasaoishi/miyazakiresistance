module MiyazakiResistance
  module Enhance
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
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

      private

      def finder_attribute_names(name)
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
end
