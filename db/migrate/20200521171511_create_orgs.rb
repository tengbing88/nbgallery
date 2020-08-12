class CreateOrgs < ActiveRecord::Migration
  def change
    create_table :orgs do |t|
      t.string :name
      t.integer :parent_id
      t.integer :users
      t.integer :notebooks
      t.integer :notebook_views
      t.integer :notebook_runs
      t.integer :notebook_stars
      t.integer :notebook_shares
      t.integer :downloads

      t.timestamps null: false
    end
  end
end
