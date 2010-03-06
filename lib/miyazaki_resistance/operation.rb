module MiyazakiResistance
  class Base
    OPERATIONS = {
      "=" => {:string => TokyoTyrant::RDBQRY::QCSTREQ, :number => TokyoTyrant::RDBQRY::QCNUMEQ},
      "!=" => {:string => TokyoTyrant::RDBQRY::QCNEGATE | TokyoTyrant::RDBQRY::QCSTREQ, :number => TokyoTyrant::RDBQRY::QCNEGATE | TokyoTyrant::RDBQRY::QCNUMEQ},
      "<>" => {:string => TokyoTyrant::RDBQRY::QCNEGATE | TokyoTyrant::RDBQRY::QCSTREQ, :number => TokyoTyrant::RDBQRY::QCNEGATE | TokyoTyrant::RDBQRY::QCNUMEQ},
      "include" => {:string => TokyoTyrant::RDBQRY::QCSTRINC},
      "begin" => {:string => TokyoTyrant::RDBQRY::QCSTRBW},
      "end" => {:string => TokyoTyrant::RDBQRY::QCSTREW},
      "allinclude" => {:string => TokyoTyrant::RDBQRY::QCSTRAND},
      "anyinclude" => {:string => TokyoTyrant::RDBQRY::QCSTROR},
      "in" => {:string => TokyoTyrant::RDBQRY::QCSTROREQ, :number => TokyoTyrant::RDBQRY::QCNUMOREQ},
      "=~" => {:string => TokyoTyrant::RDBQRY::QCSTRRX},
      "!~" => {:string => TokyoTyrant::RDBQRY::QCNEGATE | TokyoTyrant::RDBQRY::QCSTRRX},
      ">" => {:number => TokyoTyrant::RDBQRY::QCNUMGT},
      ">=" => {:number => TokyoTyrant::RDBQRY::QCNUMGE},
      "<" => {:number => TokyoTyrant::RDBQRY::QCNUMLT},
      "<=" => {:number => TokyoTyrant::RDBQRY::QCNUMLE},
      "between" => {:number => TokyoTyrant::RDBQRY::QCNUMBT}
    }
    NOT_OPERATIONS = %w|include begin end allinclude anyinclude in between|
    DATE_TYPE = [:datetime, :date]
  end
end
