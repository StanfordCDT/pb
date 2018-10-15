class CreateElectionUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :election_users do |t|
      t.references :election, null: false
      t.references :user, null: false
      t.integer :status, null: false
      t.boolean :active, default: true

      t.timestamps null: false
    end
  end
end
