class CreateHistories < ActiveRecord::Migration[7.1]
  def change
    create_table :histories do |t|
      t.string :session_id
      t.text :prompt
      t.text :response

      t.timestamps
    end
    add_index :histories, :session_id
  end
end
