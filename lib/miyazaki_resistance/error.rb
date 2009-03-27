module MiyazakiResistance
  class MiyazakiResistanceError < StandardError; end
  class TokyoTyrantConnectError < MiyazakiResistanceError; end
  class NewRecordError < MiyazakiResistanceError; end
  class QueryError < MiyazakiResistanceError; end
  class MasterDropError < MiyazakiResistanceError; end
  class AllTimeoutORConnectionPoolEmpty < MiyazakiResistanceError; end
end

