class AddUsesSliderToProjects < ActiveRecord::Migration[5.2]
  def change
    add_column :projects, :uses_slider, :boolean, default: false
  end
end
