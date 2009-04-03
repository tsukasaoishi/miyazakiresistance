module TokyoTyrant
  class RDB
    attr_accessor :host, :port

    def open_with_save_params(host, port = 0)
      @host = host
      @port = port
      open_without_save_params(host, port)
    end
    alias_method :open_without_save_params, :open
    alias_method :open, :open_with_save_params
  end
end
