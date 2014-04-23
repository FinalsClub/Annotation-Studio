class AddFinalclubWorkIdToDocument < ActiveRecord::Migration
  def up
    add_column :documents, :final_club_work_id, :integer
  end

  def down
    remove_column :documents, :final_club_work_id
  end
end
