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

    def to_hash
      config_hash = block_given? ? yield(config) : config&.to_hash
      { 'rule_class' => self.class.name, 'config' => config_hash }
    end

    def self.from_hash(hash)
      raise ArgumentError unless hash.fetch('rule_class') == name

      config_hash = hash.fetch('config')
      new(block_given? ? yield(config_hash) : config_hash)
    end

    def self.context_reader(*keys)
      keys.each do |key|
        define_method(key) { context.fetch(key) }
      end
    end

    def self.context_writer(*keys)
      keys.each do |key|
        define_method("#{key}=") { |value| context[key] = value }
      end
    end

    def self.context_accessor(*keys)
      context_reader(*keys)
      context_writer(*keys)
    end

    def self.config_reader(*keys)
      keys.each do |key|
        define_method(key) { config.fetch(key) }
      end
    end
  end
end
