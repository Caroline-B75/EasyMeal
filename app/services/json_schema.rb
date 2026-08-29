# frozen_string_literal: true

# Les deux tournures de JSON Schema qu'exigent les sorties structurées de l'API
# Claude. Elles ne savent rien de ce qu'on demande à l'IA : c'est de la grammaire,
# partagée par toutes les demandes du projet (Recipes::ClaudePrompts pour les
# recettes, Ingredients::DensityPrompt pour les densités).
module JsonSchema
  module_function

  # Objet strict, tel que les sorties structurées l'exigent : aucune propriété en
  # plus, et toutes obligatoires.
  def strict_object(**properties)
    {
      type:                 "object",
      properties:           properties,
      required:             properties.keys.map(&:to_s),
      additionalProperties: false
    }
  end

  # Champ facultatif. Toute propriété étant obligatoire, un champ « vide » se
  # déclare en acceptant null en plus de son type.
  def nullable(type, enum: nil)
    value = { type: type }
    value[:enum] = enum if enum

    { anyOf: [ value, { type: "null" } ] }
  end
end
