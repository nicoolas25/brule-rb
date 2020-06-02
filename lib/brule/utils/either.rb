# frozen_string_literal: true

require 'forwardable'

module Brule
  module Utils
    class Either < Brule::Rule
      TooManyMatches = Class.new(StandardError)
      NoMatchFound = Class.new(StandardError)

      extend Forwardable

      def_delegators :only_match, :apply, :trigger?, :to_tag

      config_reader 'rules'

      def to_hash
        super do |config|
          config.to_hash.tap do |config_hash|
            config_hash['rules'] = config.fetch('rules').map(&:to_hash)
          end
        end
      end

      def self.from_hash(*)
        super do |config_hash|
          config_hash.tap do |config|
            config['rules'] = config_hash.fetch('rules').map do |rule_hash|
              rule_class = Object.const_get(rule_hash.fetch('rule_class'))
              rule_class.from_hash(rule_hash)
            end
          end
        end
      end

      private

      def only_match
        matches = rules.select do |rule|
          rule.context = context
          rule.trigger?
        end

        if matches.size >= 2
          raise TooManyMatches, "Rules #{matches.join(', ')} are all a match"
        end

        if matches.empty?
          raise NoMatchFound, "No rules from #{rules.join(', ')} is a match"
        end

        matches.first
      end
    end
  end
end
