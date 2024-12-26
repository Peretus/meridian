require "test_helper"

class ClassificationTest < ActiveSupport::TestCase
  test "valid classification with all required attributes" do
    classification = classifications(:human_positive)
    assert classification.valid?
  end

  test "should not save classification without classifier_type" do
    classification = Classification.new(
      location: locations(:valid_location),
      is_result: true
    )
    assert_not classification.valid?
    assert_includes classification.errors[:classifier_type], "can't be blank"
  end

  test "should not save classification with invalid classifier_type" do
    classification = Classification.new(
      location: locations(:valid_location),
      classifier_type: 'invalid',
      is_result: true
    )
    assert_not classification.valid?
    assert_includes classification.errors[:classifier_type], "is not included in the list"
  end

  test "should require model_version for machine classifications" do
    classification = Classification.new(
      location: locations(:valid_location),
      classifier_type: 'machine',
      is_result: true
    )
    assert_not classification.valid?
    assert_includes classification.errors[:model_version], "can't be blank"
  end

  test "should not require model_version for human classifications" do
    classification = Classification.new(
      location: locations(:valid_location),
      classifier_type: 'human',
      is_result: true
    )
    assert classification.valid?
  end

  test "scopes return correct classifications" do
    assert_includes Classification.by_human, classifications(:human_positive)
    assert_includes Classification.by_machine, classifications(:machine_positive)
    assert_includes Classification.positive_results, classifications(:human_positive)
    assert_includes Classification.negative_results, classifications(:human_negative)
  end

  test "latest scope returns most recent classification" do
    location = locations(:valid_location)
    
    # Create an older classification
    old_classification = Classification.create!(
      location: location,
      classifier_type: 'human',
      is_result: true,
      created_at: 1.day.ago
    )

    # Create a newer classification
    new_classification = Classification.create!(
      location: location,
      classifier_type: 'human',
      is_result: false
    )

    assert_equal new_classification, location.classifications.latest.first
  end
end 