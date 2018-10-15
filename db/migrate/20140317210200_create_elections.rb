class CreateElections < ActiveRecord::Migration[5.2]
  def change
    create_table :elections do |t|
      t.string :name, null: false
      t.string :description
      t.string :slug, null: false
      t.integer :budget
      t.string :time_zone
      t.text :config_yaml
      t.boolean :allow_admins_to_update_election, default: false, null: false
      t.boolean :allow_admins_to_see_voter_data, default: false, null: false
      t.boolean :allow_admins_to_see_exact_results, default: false, null: false

      t.timestamps null: false
    end

    add_index :elections, :slug, unique: true
  end
end
