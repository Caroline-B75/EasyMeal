# frozen_string_literal: true

require "rails_helper"

# Qui se fait estimer, et qui ne se fait pas estimer. Un appel à l'IA se paie :
# ce service ne doit en lancer que là où une densité débloquerait vraiment une
# conversion.
RSpec.describe Ingredients::MissingDensityService do
  def ai_ingredient(name, unit)
    { "name" => name, "quantity" => 1, "unit" => unit }
  end

  # « 1 c. à s. de farine » : le catalogue pèse, la recette dose. Sans densité,
  # la quantité repartirait telle quelle dans le formulaire.
  it "lance l'estimation d'un ingrédient au poids dosé à la cuillère" do
    farine = create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g")

    expect { described_class.call([ ai_ingredient("farine", "cas") ]) }
      .to have_enqueued_job(Ingredients::EstimateDensityJob).with(farine)
  end

  it "ne redemande pas une densité déjà connue" do
    create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g",
                        density_g_per_ml: 0.55, density_source: :manual)

    expect { described_class.call([ ai_ingredient("farine", "cas") ]) }
      .not_to have_enqueued_job(Ingredients::EstimateDensityJob)
  end

  # La conversion se fait déjà sans densité : une cuillère est un volume.
  it "n'estime rien quand la conversion aboutit déjà" do
    create(:ingredient, name: "Huile d'olive", unit_group: :volume, base_unit: "ml")

    expect { described_class.call([ ai_ingredient("huile d'olive", "cas") ]) }
      .not_to have_enqueued_job(Ingredients::EstimateDensityJob)
  end

  # « 2 tranches de jambon » : aucune densité ne relierait ces deux façons de
  # dire, c'est le poids d'une pièce qui manque. Inutile d'appeler l'IA.
  it "n'estime rien quand aucune densité ne débloquerait la conversion" do
    create(:ingredient, name: "Jambon", unit_group: :mass, base_unit: "g")

    expect { described_class.call([ ai_ingredient("jambon", "tranches") ]) }
      .not_to have_enqueued_job(Ingredients::EstimateDensityJob)
  end

  # Un rapprochement approximatif n'est pas encore tranché par l'utilisatrice :
  # estimer la densité d'un ingrédient qu'elle va peut-être rejeter serait un
  # appel pour rien.
  it "s'en tient aux ingrédients reconnus sans ambiguïté" do
    create(:ingredient, name: "Farine de sarrasin", unit_group: :mass, base_unit: "g")

    expect { described_class.call([ ai_ingredient("farine de sarrazin", "cas") ]) }
      .not_to have_enqueued_job(Ingredients::EstimateDensityJob)
  end

  it "ignore une ligne sans unité comme un tableau vide" do
    create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g")

    expect { described_class.call([ ai_ingredient("farine", nil) ]) }
      .not_to have_enqueued_job(Ingredients::EstimateDensityJob)
    expect { described_class.call(nil) }
      .not_to have_enqueued_job(Ingredients::EstimateDensityJob)
  end

  # Deux lignes peuvent viser le même ingrédient : deux jobs concurrents
  # feraient deux fois le même appel, chacun croyant la densité inconnue.
  it "ne lance qu'une estimation par ingrédient" do
    create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g", aliases: [ "farine tamisée" ])

    expect { described_class.call([ ai_ingredient("farine", "cas"), ai_ingredient("farine tamisée", "cac") ]) }
      .to have_enqueued_job(Ingredients::EstimateDensityJob).once
  end
end
