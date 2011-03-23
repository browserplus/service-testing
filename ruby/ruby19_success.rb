#--
#
# Author:: Nathaniel Talbott.
# Copyright:: Copyright (c) 2000-2002 Nathaniel Talbott. All rights reserved.
# License:: Ruby license.

module Test
  module Unit

    # Encapsulates a test success. Created by Test::Unit::TestCase.
    class Success
      attr_reader :test_id, :test_name
      
      SINGLE_CHARACTER = '.'

      # Creates a new Success with the given location and
      # message.
      def initialize(test_id, test_name)
        @test_id = test_id
        @test_name = test_name
      end
      
      # Returns a single character representation of a success.
      def single_character_display
        SINGLE_CHARACTER
      end

      # Returns a brief version of the error description.
      def short_display
        "#@test_name: ."
      end

      # Returns a verbose version of the error description.
      def long_display
        "#@test_name: ."
        "Success:\n#@test_name:\n#@message"
      end

      # Overridden to return long_display.
      def to_s
        long_display
      end
    end
  end
end
