class CreateVoterRegistrationRecords < ActiveRecord::Migration
  def change
    create_table :voter_registration_records do |t|
      t.references :election, null: false
      t.references :user, null: false
      t.references :voter, null: false
      t.text :data

      t.timestamps null: false
    end
  end
end
