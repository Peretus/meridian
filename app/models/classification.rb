class Classification < ApplicationRecord
  belongs_to :location
  belongs_to :user, optional: true

  CLASSIFIER_TYPES = %w[human machine].freeze

  validates :classifier_type, presence: true, inclusion: { in: CLASSIFIER_TYPES }
  validates :is_result, inclusion: { in: [true, false] }
  validates :model_version, presence: true, if: -> { classifier_type == 'machine' }

  scope :latest, -> { order(created_at: :desc) }
  scope :by_machine, -> { where(classifier_type: 'machine') }
  scope :by_human, -> { where(classifier_type: 'human') }
  scope :positive_results, -> { where(is_result: true) }
  scope :negative_results, -> { where(is_result: false) }

  # For backward compatibility with anchorage-specific code
  def anchorage?
    is_result
  end
end 