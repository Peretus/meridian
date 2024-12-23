class CreateInitialSchema < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'postgis'
    
    create_table :locations do |t|
      t.st_point :coordinates, null: false
      t.string :source, null: false
      t.datetime :fetched_at
      t.timestamps
      
      t.index :coordinates, using: :gist
    end
  end
end 