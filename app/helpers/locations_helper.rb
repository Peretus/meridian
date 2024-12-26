module LocationsHelper
  def classification_border_class(location)
    latest_classification = location.latest_classification

    if latest_classification&.classifier_type == 'human'
      latest_classification.is_result ? 'border-green-500' : 'border-red-500'
    elsif latest_classification&.classifier_type == 'machine'
      latest_classification.is_result ? 'border-blue-500' : 'border-yellow-500'
    else
      'border-gray-300'
    end
  end
end 