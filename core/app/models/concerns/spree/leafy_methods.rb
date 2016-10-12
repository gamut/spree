module Spree
  module LeafyMethods
    extend ActiveSupport::Concern
    included do
      after_save :add_loose_variants
    end

    def add_loose_variants
      return unless is_loose_leaf?

      add_weight_option_type unless has_weight_option_type?

      missing_weight_option_values.each do | missing_value |
        variant = Spree::Variant.create( product_id: self.id )
        variant.option_values << missing_value
        fraction = missing_value.name.gsub(/[^\d\.]/, '').to_f
        variant.weight = fraction
        variant.save!
        fractional_price = fraction * self.price_in(Spree::Config[:currency]).amount
        price = variant.prices.first
        price.amount = fractional_price.to_f
        price.save!
      end

      return
    end

    def name
      read_attribute(:name).gsub('&shy;','')
    end

    def html_name
      read_attribute(:name)
    end

    def update_variety(new_variety)
      if variety_taxon.nil?
        taxons << Spree::Taxon.where( ' parent_id = 1 AND name LIKE ?', new_variety )
      elsif variety_taxon.name.downcase != new_variety
        taxons.delete(variety_taxon)
        taxons << Spree::Taxon.where( ' parent_id = 1 AND name LIKE ?', new_variety )
      end
    end

    def variety_taxon
      taxons.where(parent_id: 1).try(:first)
    end

    def missing_weight_option_values
      weight_option_type = Spree::OptionType.where(name: 'Weight').first
      required_option_values = Spree::OptionValue.where( option_type_id: weight_option_type.id )

      actual_option_values = variants.map { |variant|
        variant.option_values.where( id: required_option_values )
      }.flatten

      (required_option_values - actual_option_values )
    end

    def is_loose_leaf?
      taxons.any? && taxons.where( name: 'Loose Leaf' ).any?
    end

    def add_weight_option_type
      option_types << Spree::OptionType.where(name: 'Weight').first
    end

    def has_weight_option_type?
      option_types.where( name: 'Weight' ).any?
    end

  end
end
