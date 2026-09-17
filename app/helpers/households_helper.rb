# frozen_string_literal: true

# Libellés du foyer : pages « Mon foyer » et « Rejoindre un foyer ».
module HouseholdsHelper
  # Un membre tel qu'on le reconnaît : son prénom, et son pseudo — seul
  # identifiant unique, deux membres pouvant porter le même prénom.
  # @param user [User]
  # @return [String] ex. « Caroline (@Caro) »
  def household_member_label(user)
    "#{user.first_name} (@#{user.username})"
  end

  # Les autres membres du foyer, par leur pseudo — « @marc », « @marc et @lea ».
  # Sert à dire, là où c'est utile, avec qui les menus sont partagés.
  # @param user [User]
  # @return [String, nil] nil quand on est seul dans son foyer
  def household_mates_sentence(user)
    mates = user.household.members.where.not(id: user.id).order(:created_at)
    return if mates.empty?

    mates.map { |mate| "@#{mate.username}" }.to_sentence
  end

  # Ce que la personne invitée laisse derrière elle en rejoignant un foyer, dit
  # avant qu'elle confirme (cf. Household#admit!) :
  #   - elle partage déjà un foyer : elle le quitte, ses menus y restent ;
  #   - elle vit seule dans le sien : ses menus la suivent dans l'historique.
  # @param user [User] la personne invitée
  # @return [String, nil] nil quand elle n'a ni foyer partagé ni menu
  def household_join_consequence(user)
    housemates = user.household.members.where.not(id: user.id).order(:created_at).to_a
    if housemates.any?
      return "Tu quitteras le foyer que tu partages avec " \
             "#{housemates.map { |mate| household_member_label(mate) }.to_sentence} : ses menus y restent."
    end

    menus_count = user.menus.count
    case menus_count
    when 0 then nil
    when 1 then "Ton menu rejoindra l'historique du foyer."
    else        "Tes #{menus_count} menus rejoindront l'historique du foyer."
    end
  end
end
