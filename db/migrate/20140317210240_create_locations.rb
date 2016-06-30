class CreateLocations < ActiveRecord::Migration
  def change
    create_table :locations do |t|
      t.references :election, null: false
      t.string :name

      t.timestamps null: false
    end
  end
end
