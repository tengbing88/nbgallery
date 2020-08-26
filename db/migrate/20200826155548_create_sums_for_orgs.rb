class CreateSumsForOrgs < ActiveRecord::Migration
  def change
    create_table :sums_for_orgs do |t|
      t.string :entity_type
      t.integer :type_id
      t.integer :score
      t.integer :users
      t.integer :notebooks
      t.integer :groups
      t.integer :notebook_views
      t.integer :notebook_runs
      t.integer :notebook_stars
      t.integer :notebook_shares
      t.integer :notebook_downloads

      t.timestamps null: false
    end
  end
end
