object @product
cache [I18n.locale, @current_user_roles.include?('admin'), current_currency, root_object]

attributes *product_attributes, :sale_price, :favorite_count

node(:display_price) { |p| p.display_price.to_s }
node(:display_sale_price) { |p| p.display_sale_price }
node(:display_name) { |p| p.display_name }
node(:has_variants) { |p| p.has_variants? }
node(:taxon_ids) { |p| p.taxon_ids }
node(:affiliate_url) { |p| p.master.affiliate_url }
node(:favorited_by_current_user) { |p| p.favorited_by?(@current_api_user) }

child :master => :master do
  extends "spree/api/v1/variants/small"
end

child :variants => :variants do
  extends "spree/api/v1/variants/small"
end

child :option_types => :option_types do
  attributes *option_type_attributes
end

child :product_properties => :product_properties do
  attributes *product_property_attributes
end

child :classifications => :classifications do
  attributes :taxon_id, :position

  child(:taxon) do
    extends "spree/api/v1/taxons/show"
  end
end
