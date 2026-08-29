# frozen_string_literal: true

module Ingredients
  # Ce qu'on demande à l'IA au sujet d'un ingrédient du catalogue : sa densité,
  # la donnée qui manque pour peser ce qu'une recette dose à la cuillère.
  #
  # Une classe à part de Recipes::ClaudePrompts, parce que la question n'est pas
  # la même : celle-là lit une recette, celle-ci interroge le catalogue. On la
  # pose sur l'ingrédient, une fois pour toutes, et non sur la recette à chaque
  # import — la densité est une propriété de la farine, pas de la recette qui
  # l'emploie.
  #
  # Comme pour les recettes, tout le français adressé à Claude vit ici :
  # Recipes::ClaudeClient poste la demande sans rien savoir de son contenu.
  class DensityPrompt
    # Consigne système propre à cette demande : celle de l'import parlerait
    # d'extraire des recettes, ce qui n'a rien à voir avec la question posée.
    SYSTEM = "Tu es un expert des mesures en cuisine. Tu connais la masse volumique " \
             "des ingrédients telle qu'on les dose avec une cuillère ou un verre mesureur."

    # @param name [String] nom de l'ingrédient
    # @return [Hash] { messages:, schema:, system: } pour ClaudeClient
    def self.request(name)
      message = { role: "user", content: <<~PROMPT }
        Quelle est la masse d'un millilitre de cet ingrédient, en grammes, tel qu'on
        le mesure en cuisine — foisonné dans une cuillère ou un verre mesureur, ni
        tassé ni compacté ?

        Ingrédient : #{name}

        Réponds null plutôt que d'approcher au hasard dans deux cas : l'ingrédient ne
        se mesure pas au volume (il se compte à la pièce, ou se pèse en morceaux), ou
        sa densité varie trop d'un conditionnement à l'autre. Une densité inventée
        fausserait des quantités sans que personne ne le voie ; une absence, elle, se
        signale.
      PROMPT

      {
        messages: [ message ],
        schema:   JsonSchema.strict_object(density_g_per_ml: JsonSchema.nullable("number")),
        system:   SYSTEM
      }
    end
  end
end
