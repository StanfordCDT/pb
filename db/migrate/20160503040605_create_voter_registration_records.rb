class CreateVoterRegistrationRecords < ActiveRecord::Migration[5.2]
  def change
    create_table :voter_registration_records do |t|
      t.references :election, null: false
      t.references :user
      t.references :voter
      t.text :data

      t.timestamps null: false
    end
  end
end
