class CreateProjects < ActiveRecord::Migration[5.2]
  def up
    create_table :projects do |t|
      t.references :election, null: false
      t.references :category
      t.string :number
      t.integer :cost
      t.boolean :adjustable_cost, default: false
      t.integer :cost_min, default: 0
      t.integer :cost_step, default: 1
      t.string :map_geometry
      t.string :image
      t.integer :external_vote_count  # TODO: rename this to external_approval_vote_count or create a new table for this
      t.integer :sort_order
      t.text :data

      t.timestamps null: false
    end
    Project.create_translation_table! ({
      :title => :string,
      :description => :text,
      :details => :text,
      :address => :string,
      :partner => :string,
      :committee => :string,
      :video_url => :string,
      :image_description => :text,
    })
  end

  def down
    drop_table :projects
    Project.drop_translation_table!
  end
end
