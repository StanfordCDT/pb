class AddUsesSliderToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :uses_slider, :boolean, default: false
  end
end
