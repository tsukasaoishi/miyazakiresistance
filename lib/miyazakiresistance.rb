$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'tokyotyrant'
require 'timeout'
require 'logger'
require 'miyazaki_resistance/tokyo_connection'
require 'miyazaki_resistance/miyazaki_logger'
require 'miyazaki_resistance/base'
require 'miyazaki_resistance/error'

module MiyazakiResistance
  VERSION = '0.0.3'
end

MiyazakiResistance::Base.class_eval do
  include MiyazakiResistance::TokyoConnection
  include MiyazakiResistance::MiyazakiLogger

  OPERATIONS = {
    "=" => {:string => TokyoTyrant::RDBQRY::QCSTREQ, :integer => TokyoTyrant::RDBQRY::QCNUMEQ},
    "!=" => {:string => ~TokyoTyrant::RDBQRY::QCSTREQ, :integer => ~TokyoTyrant::RDBQRY::QCNUMEQ},
    "<>" => {:string => ~TokyoTyrant::RDBQRY::QCSTREQ, :integer => ~TokyoTyrant::RDBQRY::QCNUMEQ},
    "include" => {:string => TokyoTyrant::RDBQRY::QCSTRINC},
    "begin" => {:string => TokyoTyrant::RDBQRY::QCSTRBW},
    "end" => {:string => TokyoTyrant::RDBQRY::QCSTREW},
    "allinclude" => {:string => TokyoTyrant::RDBQRY::QCSTRAND},
    "anyinclude" => {:string => TokyoTyrant::RDBQRY::QCSTROR},
    "in" => {:string => TokyoTyrant::RDBQRY::QCSTROREQ, :integer => TokyoTyrant::RDBQRY::QCNUMOREQ},
    "=~" => {:string => TokyoTyrant::RDBQRY::QCSTRRX},
    "!~" => {:string => ~TokyoTyrant::RDBQRY::QCSTRRX},
    ">" => {:integer => TokyoTyrant::RDBQRY::QCNUMGT},
    ">=" => {:integer => TokyoTyrant::RDBQRY::QCNUMGE},
    "<" => {:integer => TokyoTyrant::RDBQRY::QCNUMLT},
    "<=" => {:integer => TokyoTyrant::RDBQRY::QCNUMLE},
    "between" => {:integer => TokyoTyrant::RDBQRY::QCNUMBT}
  }
  NOT_OPERATIONS = %w|include begin end allinclude anyinclude in between|
  DATE_TYPE = [:datetime, :date]
end
