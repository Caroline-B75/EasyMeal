# frozen_string_literal: true

module Recipes
  # Traduit ce que l'IA a extrait en brouillon de recette, prêt pour le
  # formulaire de validation.
  #
  # Le brouillon arrive pré-coché : l'IA propose difficulté, régime, moments,
  # budget et tags, l'utilisatrice confirme ou corrige à la validation. Chaque
  # suggestion repasse par le vocabulaire connu — le schéma de sortie y contraint
  # déjà l'IA, mais un import n'a pas à faire confiance à ce qu'on lui rend.
  #
  # Vit à côté d'ExtractorService plutôt que dans le contrôleur : depuis que
  # l'extraction se joue dans un job, c'est lui qui construit le brouillon.
  class DraftBuilder
    def self.call(import, data)
      new(import, data).build
    end

    def initialize(import, data)
      @import = import
      @data   = data
    end

    # @return [Recipe] brouillon NON sauvegardé — l'appelant décide quand écrire.
    def build
      recipe = Recipe.new(
        status:            :draft,
        source_type:       @import.source_type,
        source_url:        @import.source_url,
        ai_raw_data:       @data,
        name:              @data["name"].presence || Recipe::PLACEHOLDER_NAME,
        description:       @data["description"],
        default_servings:  [ @data["default_servings"].to_i, 1 ].max,
        prep_time_minutes: @data["prep_time_minutes"],
        cook_time_minutes: @data["cook_time_minutes"],
        difficulty:        valid_enum(Recipe.difficulties, @data["difficulty"]),
        diet:              valid_enum(Recipe.diets, @data["diet"]) || "omnivore",
        price:             valid_enum(Recipe.prices, @data["price"]),
        meal_types:        known_meal_types(@data["meal_types"]),
        tags:              catalog_tags(@data["tags"]),
        appliance:         @data["appliance"],
        instructions:      @data["instructions"]
      )

      attach_source_photo(recipe)
      recipe
    end

    private

    # La page photographiée reste attachée au brouillon comme pièce de référence
    # pour la validation (jamais comme photo du plat).
    #
    # C'est le fichier de l'import qui est repris tel quel, pas une copie : le
    # même octet n'a pas à être payé deux fois chez Cloudinary. Le partage n'est
    # que momentané — ImportJob détache l'import dès le brouillon écrit, ce qui
    # laisse le brouillon seul propriétaire du fichier.
    def attach_source_photo(recipe)
      return unless @import.source_photo.attached?

      recipe.source_photo.attach(@import.source_photo.blob)
    end

    # Retourne la valeur uniquement si elle appartient à l'enum, nil sinon.
    def valid_enum(enum_hash, value)
      enum_hash.key?(value) ? value : nil
    end

    # Moments retenus, rangés dans l'ordre où la journée se déroule ; un moment
    # inconnu est écarté plutôt que de faire échouer la création du brouillon
    # (HasMealTypes valide le vocabulaire, brouillons compris).
    def known_meal_types(suggested)
      MealTypes::MEAL_TYPES & Array(suggested).map(&:to_s)
    end

    # Tags du catalogue portant l'un des noms suggérés, insensible à la casse.
    # Aucun tag n'est créé : un nom inconnu est ignoré silencieusement.
    def catalog_tags(names)
      names = Array(names).filter_map { |name| name.to_s.strip.downcase.presence }
      return [] if names.empty?

      Tag.where("LOWER(name) IN (?)", names)
    end
  end
end
