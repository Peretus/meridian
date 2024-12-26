module LocationsHelper
  def classification_border_class(location)
    case location.classification
    when 'result'
      'border-emerald-500'  # Green border for results
    when 'not_result'
      'border-rose-500'     # Red border for non-results
    else
      'border-slate-700'    # Dark gray border for pending/unclassified
    end
  end
end 