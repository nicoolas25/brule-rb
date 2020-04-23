require 'forwardable'

module Brule
  module Utils
    class Either < Brule::Rule
      TooManyMatches = Class.new(StandardError)
      NoMatchFound = Class.new(StandardError)

      extend Forwardable

      def_delegators :only_match, :apply, :trigger?, :to_tag

      config_reader :rules

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
