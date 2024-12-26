class CreateClassifications < ActiveRecord::Migration[7.1]
  def change
    create_table :classifications do |t|
      t.references :location, null: false, foreign_key: true
      t.string :classifier_type, null: false  # 'human' or 'machine'
      t.boolean :is_result, null: false      # true if it is the thing we're looking for (e.g., is an anchorage)
      t.string :model_version               # for machine classifications (e.g., teachable machine model version)
      t.references :user                    # for future use with human classifications
      
      t.timestamps
    end

    # Add an index for quick lookups of latest classifications
    add_index :classifications, [:location_id, :created_at]
  end
end 