require "base64"

class RecipeImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_import

  # GET /recipe_imports/new
  def new
  end

  # POST /recipe_imports
  # Appelle le service d'extraction IA, crée un brouillon et redirige vers le formulaire de review.
  def create
    extracted = extract_from_source
    recipe    = build_draft_recipe(extracted)

    if recipe.save
      redirect_to edit_recipe_path(recipe),
        notice: "Recette extraite ! Complétez et validez avant de publier."
    else
      back_to_form "Impossible de créer le brouillon : #{recipe.errors.full_messages.to_sentence}"
    end
  rescue Recipes::ExtractionError => e
    back_to_form "Extraction échouée : #{e.message}"
  end

  private

  # Retour au formulaire d'import après un échec. L'extraction dure 15 à 30 s :
  # faire ressaisir la source serait la punition de trop. L'URL repart donc dans
  # la redirection (la vue la relit via params[:source_url] et pré-remplit le
  # champ) ; un champ fichier, lui, ne peut pas être re-rempli par le navigateur,
  # alors on dit franchement ce qui reste à faire.
  def back_to_form(reason)
    case params[:source_type]
    when "url"
      redirect_to new_recipe_import_path(source_url: params[:source_url].presence), alert: reason
    when "photo"
      redirect_to new_recipe_import_path, alert: "#{reason} — choisis à nouveau la photo."
    else
      redirect_to new_recipe_import_path, alert: reason
    end
  end

  def authorize_import
    authorize :recipe_import
  end

  def extract_from_source
    case params[:source_type]
    when "url"
      raise Recipes::ExtractionError, "Veuillez saisir une URL" if params[:source_url].blank?
      Recipes::ExtractorService.from_url(params[:source_url].strip)
    when "photo"
      file = params[:photo_file]
      raise Recipes::ExtractionError, "Veuillez choisir une image" if file.blank?
      base64 = Base64.strict_encode64(file.read)
      Recipes::ExtractorService.from_photo(base64, media_type: file.content_type)
    else
      raise Recipes::ExtractionError, "Source non reconnue"
    end
  end

  def build_draft_recipe(data)
    Recipe.new(
      status:            :draft,
      source_type:       params[:source_type],
      source_url:        params[:source_url].presence,
      ai_raw_data:       data,
      name:              data["name"].presence || Recipe::PLACEHOLDER_NAME,
      description:       data["description"],
      default_servings:  [ data["default_servings"].to_i, 1 ].max,
      prep_time_minutes: data["prep_time_minutes"],
      cook_time_minutes: data["cook_time_minutes"],
      difficulty:        valid_enum(Recipe.difficulties, data["difficulty"]),
      diet:              valid_enum(Recipe.diets, data["diet"]) || "omnivore",
      appliance:         data["appliance"],
      instructions:      data["instructions"]
    )
  end

  # Retourne la valeur uniquement si elle appartient à l'enum, nil sinon.
  def valid_enum(enum_hash, value)
    enum_hash.key?(value) ? value : nil
  end
end
