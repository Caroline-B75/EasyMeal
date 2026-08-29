class RecipeImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_import

  SUCCESS_NOTICE = "Recette extraite ! Complétez et validez avant de publier.".freeze

  # GET /recipe_imports/new
  def new
  end

  # POST /recipe_imports
  # Enregistre la commande, puis confie le travail long au job : la requête
  # répond aussitôt, et l'extraction — jusqu'à 60 s — ne peut plus être coupée
  # par le routeur de l'hébergeur, qui abandonne une requête vers 30 s.
  def create
    reason = missing_source_reason
    return back_to_form(reason) if reason

    import = build_import

    if import.save
      Recipes::ImportJob.perform_later(import)
      redirect_to recipe_import_path(import)
    else
      back_to_form(import.errors.full_messages.to_sentence)
    end
  end

  # GET /recipe_imports/:id
  # La page d'attente. Elle revient d'elle-même toutes les deux secondes : cette
  # action rend le patientage tant que le job travaille, puis emmène au
  # formulaire de validation dès qu'il a réussi.
  def show
    @import = current_user.recipe_imports.find(params[:id])

    return redirect_to(edit_recipe_path(@import.recipe), notice: SUCCESS_NOTICE) if @import.succeeded?

    # Sinon : la page d'attente se rend, sauf si le job a échoué.
    back_to_form(@import.error_message, @import.source_type, @import.source_url) if @import.failed?
  end

  private

  def build_import
    import = current_user.recipe_imports.new(
      source_type: params[:source_type],
      source_url:  params[:source_url]&.strip.presence
    )
    import.source_photo.attach(photo_file) if photo_file.present?
    import
  end

  # Ce qui manque pour lancer un import, dit comme le formulaire le comprend.
  # Le modèle valide la même chose structurellement ; ce garde-fou-ci existe pour
  # la phrase montrée à l'utilisatrice.
  def missing_source_reason
    case params[:source_type]
    when "url"   then "Veuillez saisir une URL" if params[:source_url].blank?
    when "photo" then "Veuillez choisir une image" if photo_file.blank?
    else "Source non reconnue"
    end
  end

  # Retour au formulaire d'import après un échec. L'extraction dure 15 à 30 s :
  # faire ressaisir la source serait la punition de trop. L'URL repart donc dans
  # la redirection (la vue la relit via params[:source_url] et pré-remplit le
  # champ) ; un champ fichier, lui, ne peut pas être re-rempli par le navigateur,
  # alors on dit franchement ce qui reste à faire.
  def back_to_form(reason, source_type = params[:source_type], source_url = params[:source_url])
    case source_type
    when "url"
      redirect_to new_recipe_import_path(source_url: source_url.presence), alert: reason
    when "photo"
      redirect_to new_recipe_import_path, alert: "#{reason} — choisis à nouveau la photo."
    else
      redirect_to new_recipe_import_path, alert: reason
    end
  end

  def authorize_import
    authorize :recipe_import
  end

  # Fichier soumis par l'onglet Photo — nil pour un import par lien, même si un
  # champ fichier traînait dans les paramètres.
  def photo_file
    params[:photo_file] if params[:source_type] == "photo"
  end
end
