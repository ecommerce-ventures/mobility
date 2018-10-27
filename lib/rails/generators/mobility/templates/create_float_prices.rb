class CreateFloatPrices < <%= activerecord_migration_class %>

  def change
    create_table :mobility_float_prices do |t|
      t.string :currency, null: false
      t.string :key, null: false
      t.float :value
      t.references :priceable, polymorphic: true, index: false
      t.timestamps null: false
    end
    add_index :mobility_float_prices, [:priceable_id, :priceable_type, :currency, :key], unique: true, name: :index_mobility_float_prices_on_keys
    add_index :mobility_float_prices, [:priceable_id, :priceable_type, :key], name: :index_mobility_float_prices_on_priceable_attribute
    add_index :mobility_float_prices, [:priceable_type, :key, :value, :currency], name: :index_mobility_float_prices_on_query_keys
  end
end
