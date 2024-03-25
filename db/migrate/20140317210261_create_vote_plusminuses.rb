class CreateVotePlusminuses < ActiveRecord::Migration[5.2]
  def change
    create_table :vote_plusminuses do |t|
      t.references :voter, index: true, null: false
      t.references :project, index: true, null: false
      t.integer :plusminus, null: false

      t.timestamps null: false
    end
  end
end
