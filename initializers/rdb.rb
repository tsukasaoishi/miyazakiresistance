require 'tokyotyrant'

module TokyoTyrant
  class RDB
    attr_accessor :host, :port, :open_flag

    def set_server(host, port = 0)
      @host = host
      @port = port
    end

    def open_with_save_params(host = nil, port = 0)
      @host ||= host
      @port ||= port

      if open_without_save_params(@host, @port)
        @open_flag = true
      else
        false
      end
    end
    alias_method :open_without_save_params, :open
    alias_method :open, :open_with_save_params

    def close_with_change_flag
      if close_without_change_flag
        @open_flag = false
        true
      else
        false
      end
    end
    alias_method :close_without_change_flag, :close
    alias_method :close, :close_with_change_flag

    def open?
      @open_flag
    end
  end
end
