ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require 'rgeo'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def setup
      # Clean up any non-fixture classifications
      fixture_ids = classifications.map(&:id)
      Classification.where.not(id: fixture_ids).delete_all
    end

    def teardown
      # Clean up any non-fixture classifications
      fixture_ids = classifications.map(&:id)
      Classification.where.not(id: fixture_ids).delete_all
    end

    # Add more helper methods to be used by all tests here...
  end
end
