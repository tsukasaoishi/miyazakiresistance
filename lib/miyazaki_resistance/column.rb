module MiyazakiResistance
  class Base
    class << self
      attr_accessor :all_columns

      def column(name, type, index = :no_index)
        self.all_columns ||= {}
        name = name.to_s
        self.__send__(:attr_accessor, name)
        self.all_columns.update(name => type)
      end
      alias :set_column :column
    end
  end
end
