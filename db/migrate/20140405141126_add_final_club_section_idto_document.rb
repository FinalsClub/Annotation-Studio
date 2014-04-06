class AddFinalClubSectionIdtoDocument < ActiveRecord::Migration
  def up
    add_column :documents, :final_club_id, :integer
  end

  def down
    remove_column :documents, :final_club_id
  end
end
