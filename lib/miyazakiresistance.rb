$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'logger'
require 'timeout'
require 'tokyotyrant'

Dir.glob("#{File.join(File.dirname(__FILE__), "../initializers")}/*.rb").each{|path| require path}
Dir.glob("#{File.join(File.dirname(__FILE__), "miyazaki_resistance")}/*.rb").each{|path| require path}

module MiyazakiResistance
  VERSION = '0.1.4'
end

MiyazakiResistance::Base.class_eval do
  include MiyazakiResistance::TokyoConnection
  include MiyazakiResistance::Enhance
  include MiyazakiResistance::MiyazakiLogger

  OPERATIONS = {
    "=" => {:string => TokyoTyrant::RDBQRY::QCSTREQ, :integer => TokyoTyrant::RDBQRY::QCNUMEQ},
    "!=" => {:string => TokyoTyrant::RDBQRY::QCNEGATE | TokyoTyrant::RDBQRY::QCSTREQ, :integer => TokyoTyrant::RDBQRY::QCNEGATE | TokyoTyrant::RDBQRY::QCNUMEQ},
    "<>" => {:string => TokyoTyrant::RDBQRY::QCNEGATE | TokyoTyrant::RDBQRY::QCSTREQ, :integer => TokyoTyrant::RDBQRY::QCNEGATE | TokyoTyrant::RDBQRY::QCNUMEQ},
    "include" => {:string => TokyoTyrant::RDBQRY::QCSTRINC},
    "begin" => {:string => TokyoTyrant::RDBQRY::QCSTRBW},
    "end" => {:string => TokyoTyrant::RDBQRY::QCSTREW},
    "allinclude" => {:string => TokyoTyrant::RDBQRY::QCSTRAND},
    "anyinclude" => {:string => TokyoTyrant::RDBQRY::QCSTROR},
    "in" => {:string => TokyoTyrant::RDBQRY::QCSTROREQ, :integer => TokyoTyrant::RDBQRY::QCNUMOREQ},
    "=~" => {:string => TokyoTyrant::RDBQRY::QCSTRRX},
    "!~" => {:string => TokyoTyrant::RDBQRY::QCNEGATE | TokyoTyrant::RDBQRY::QCSTRRX},
    ">" => {:integer => TokyoTyrant::RDBQRY::QCNUMGT},
    ">=" => {:integer => TokyoTyrant::RDBQRY::QCNUMGE},
    "<" => {:integer => TokyoTyrant::RDBQRY::QCNUMLT},
    "<=" => {:integer => TokyoTyrant::RDBQRY::QCNUMLE},
    "between" => {:integer => TokyoTyrant::RDBQRY::QCNUMBT}
  }
  NOT_OPERATIONS = %w|include begin end allinclude anyinclude in between|
  DATE_TYPE = [:datetime, :date]
end
