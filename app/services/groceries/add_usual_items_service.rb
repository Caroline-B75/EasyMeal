# frozen_string_literal: true

module Groceries
  # Ajoute à la liste de courses les courses habituelles retenues dans la pop-up
  # « Mes habituelles » (UC8, étape 3), chacune avec la quantité de cette fois.
  #
  # Chaque article passe par le chemin du formulaire « Ajouter un article »
  # (AddManualItemService, en mode habituel) : même reconnaissance, même rayon,
  # même conversion. Un article déjà dans la liste y voit sa quantité
  # additionnée ; un article qui ne peut pas être ajouté est nommé dans le bilan
  # sans empêcher les autres.
  #
  # @example
  #   Groceries::AddUsualItemsService.call(menu: menu, selections: { lait => 6, cafe => 2 })
  #   # => #<struct Summary added: 1, merged: 1, failures: []>
  class AddUsualItemsService
    # Le bilan de l'ajout, qui fait le bandeau affiché ensuite.
    # - added    : lignes créées
    # - merged   : quantités additionnées à une ligne existante
    # - failures : messages des articles refusés
    Summary = Struct.new(:added, :merged, :failures, keyword_init: true) do
      # Quelque chose a-t-il rejoint la liste ?
      def any_added?
        (added + merged).positive?
      end

      # « 3 articles ajoutés à ta liste, dont 1 additionné à une ligne existante. »
      # suivi des refus éventuels.
      # @return [String]
      def message
        [ added_sentence, *failures ].compact.join(" ")
      end

      private

      def added_sentence
        return "Aucun article n'a été ajouté." unless any_added?

        total    = added + merged
        sentence = "#{total} #{total > 1 ? 'articles ajoutés' : 'article ajouté'} à ta liste"
        return "#{sentence}." if merged.zero?

        merged_part = merged > 1 ? "additionnés à des lignes existantes" : "additionné à une ligne existante"
        "#{sentence}, dont #{merged} #{merged_part}."
      end
    end

    # @param menu [Menu] menu dont on garnit la liste de courses
    # @param selections [Hash{UsualGroceryItem => Numeric}] articles retenus et quantité de cette fois
    # @return [Summary]
    def self.call(menu:, selections:)
      new(menu: menu, selections: selections).call
    end

    def initialize(menu:, selections:)
      @menu       = menu
      @selections = selections
    end

    # Une seule transaction : la liste reçoit tout l'ajout d'un coup, et les
    # écrans ouverts sur elle un seul rafraîchissement.
    def call
      summary = Summary.new(added: 0, merged: 0, failures: [])

      GroceryItem.transaction do
        @selections.each do |usual_item, quantity|
          result = AddManualItemService.call(menu: @menu, params: usual_item.entry(quantity), usual: true)
          record(summary, result)
        end
      end

      summary
    end

    private

    # Un refus se dit par ses raisons. En pratique il n'y en a qu'une : une unité
    # que l'ingrédient ne sait plus lire (le catalogue a changé depuis), et son
    # message nomme l'article.
    def record(summary, result)
      case result.status
      when :created then summary.added += 1
      when :merged  then summary.merged += 1
      else summary.failures << result.item.errors.full_messages.to_sentence
      end
    end
  end
end
