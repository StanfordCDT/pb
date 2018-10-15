class CreateVoteComparisons < ActiveRecord::Migration[5.2]
  def change
    create_table :vote_comparisons do |t|
      t.references :voter, index: true, null: false
      t.integer :first_project_id, null: false
      t.integer :first_project_cost
      t.integer :second_project_id, null: false
      t.integer :second_project_cost
      t.integer :result, null: false  # TODO: better name?
      # result = 1 means the first project wins
      # result = 0 means tie
      # result = -1 means the second project wins
      t.timestamps null: false
    end
  end
end
