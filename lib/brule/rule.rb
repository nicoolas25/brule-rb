module Brule
  Rule = Struct.new(:config) do
    attr_accessor :context

    def trigger?
      true
    end

    def apply
      raise NotImplementedError
    end

    def to_tag
      self
    end

    def self.context_reader(*symbols)
      symbols.each do |symbol|
        define_method(symbol) { context.fetch(symbol) }
      end
    end

    def self.context_writer(*symbols)
      symbols.each do |symbol|
        define_method("#{symbol}=") { |value| context[symbol] = value }
      end
    end

    def self.context_accessor(*symbols)
      context_reader(*symbols)
      context_writer(*symbols)
    end

    def self.config_reader(*symbols)
      symbols.each do |symbol|
        define_method(symbol) { config.fetch(symbol) }
      end
    end
  end
end
