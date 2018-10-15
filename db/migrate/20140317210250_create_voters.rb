class CreateVoters < ActiveRecord::Migration[5.2]
  def change
    create_table :voters do |t|
      t.references :election, null: false
      t.references :location
      t.string :authentication_method, null: false
      t.string :authentication_id, null: false
      t.string :confirmation_code
      t.datetime :confirmation_code_created_at
      t.string :ip_address
      t.text :user_agent
      t.string :stage
      t.boolean :void, default: false, null: false
      t.text :data

      t.timestamps null: false
    end

    add_index(:voters, [:election_id, :authentication_method, :authentication_id],
              unique: true, name: :index_voters_on_election_id_and_authentication)
  end
end
