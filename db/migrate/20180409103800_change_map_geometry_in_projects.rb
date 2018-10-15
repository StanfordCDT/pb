class ChangeMapGeometryInProjects < ActiveRecord::Migration[5.2]
  def change
    change_column :projects, :map_geometry, :text
  end
end
