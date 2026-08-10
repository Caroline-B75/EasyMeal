# frozen_string_literal: true

# Libellés français des valeurs d'enum, lus dans les traductions du modèle :
# activerecord.attributes.<modèle>.<enum au pluriel>.<valeur>
#
# Un seul chemin d'appel pour tout le monde — la fiche d'un enregistrement, les
# filtres d'un catalogue et les options d'un formulaire affichent forcément le
# même mot, et le français reste dans config/locales/fr.yml.
module EnumLabels
  extend ActiveSupport::Concern

  class_methods do
    # Libellé d'une valeur d'enum, quel que soit l'enregistrement.
    # Repli sur la valeur humanisée tant que la traduction n'existe pas.
    def enum_label(field, value)
      I18n.t("activerecord.attributes.#{model_name.i18n_key}.#{field.to_s.pluralize}.#{value}",
             default: value.to_s.humanize)
    end

    # Couples [ libellé, valeur ] dans l'ordre de déclaration de l'enum : la
    # forme qu'attendent les sélecteurs (listes déroulantes, segmented control).
    def enum_options(field)
      public_send(field.to_s.pluralize).keys.map { |value| [ enum_label(field, value), value ] }
    end
  end

  # Libellé de la valeur portée par CET enregistrement, avec repli quand le
  # champ est vide (« Non renseigné »).
  def human_enum_value(field, nil_label) # :reek:NilCheck
    value = send(field)
    return nil_label if value.nil?

    self.class.enum_label(field, value)
  end
end
