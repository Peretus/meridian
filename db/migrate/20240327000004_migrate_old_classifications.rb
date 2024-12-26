class MigrateOldClassifications < ActiveRecord::Migration[7.1]
  def up
    # First, let's check if the old columns exist
    return unless column_exists?(:locations, :human_classification) || column_exists?(:locations, :machine_classification)

    # Create a temporary table to store the old data
    create_table :temp_classifications do |t|
      t.bigint :location_id
      t.integer :human_classification
      t.integer :machine_classification
      t.timestamps
    end

    # Copy data to temp table
    execute <<-SQL
      INSERT INTO temp_classifications (location_id, human_classification, machine_classification, created_at, updated_at)
      SELECT id, human_classification, machine_classification, created_at, updated_at
      FROM locations
      WHERE human_classification IS NOT NULL OR machine_classification IS NOT NULL;
    SQL

    # Migrate human classifications
    execute <<-SQL
      INSERT INTO classifications (location_id, classifier_type, is_result, created_at, updated_at)
      SELECT location_id, 'human', human_classification = 1, created_at, updated_at
      FROM temp_classifications
      WHERE human_classification IS NOT NULL;
    SQL

    # Migrate machine classifications
    execute <<-SQL
      INSERT INTO classifications (location_id, classifier_type, is_result, model_version, created_at, updated_at)
      SELECT location_id, 'machine', machine_classification = 1, 'legacy_model', created_at, updated_at
      FROM temp_classifications
      WHERE machine_classification IS NOT NULL;
    SQL

    # Drop the temporary table
    drop_table :temp_classifications
  end

  def down
    # This migration is not reversible
    raise ActiveRecord::IrreversibleMigration
  end
end 