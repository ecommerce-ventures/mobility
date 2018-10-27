class CreateIntegerPrices < <%= activerecord_migration_class %>

  def change
    create_table :mobility_integer_prices do |t|
      t.string :currency, null: false
      t.string :key,    null: false
      t.integer :value
      t.references :priceable, polymorphic: true, index: false
      t.timestamps null: false
    end
    add_index :mobility_integer_prices, [:priceable_id, :priceable_type, :currency, :key], unique: true, name: :index_mobility_integer_prices_on_keys
    add_index :mobility_integer_prices, [:priceable_id, :priceable_type, :key], name: :index_mobility_integer_prices_on_priceable_attribute
  end
end
