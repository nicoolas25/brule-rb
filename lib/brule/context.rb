require 'forwardable'

module Brule
  class Context
    extend Forwardable

    def_delegators :@content, :fetch, :fetch_values, :key?, :[]=, :merge!

    def self.wrap(context)
      context.is_a?(self) ? context : new(context)
    end

    def initialize(hash = {})
      @content = hash
    end

    def [](key)
      @content.fetch(key)
    end

    def initialize_copy(orig)
      super
      @content = orig.instance_variable_get(:@content).dup
    end
  end
end
