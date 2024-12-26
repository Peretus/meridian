class AddTestClassifications < ActiveRecord::Migration[7.1]
  def up
    # Get all locations with satellite images
    locations = Location.joins("INNER JOIN active_storage_attachments ON active_storage_attachments.record_id = locations.id")
                       .where("active_storage_attachments.record_type = 'Location' AND active_storage_attachments.name = 'satellite_image'")
                       .limit(10)
    
    locations.each do |location|
      # Add some human classifications
      Classification.create!(
        location_id: location.id,
        classifier_type: 'human',
        is_result: [true, false].sample,
        created_at: Time.current,
        updated_at: Time.current
      )

      # Add some machine classifications
      Classification.create!(
        location_id: location.id,
        classifier_type: 'machine',
        is_result: [true, false].sample,
        model_version: 'test_model_v1',
        created_at: Time.current,
        updated_at: Time.current
      )
    end
  end

  def down
    Classification.delete_all
  end
end 