# frozen_string_literal: true

# Libellés du foyer : pages « Mon foyer » et « Rejoindre un foyer », et avatars
# de ses membres.
module HouseholdsHelper
  # Nombre de couleurs d'avatar (cf. .member-avatar, components.css)
  MEMBER_COLORS = 7

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

  # Couleur d'avatar d'un membre : son rang dans son foyer. Deux membres d'un
  # même foyer ne partagent donc jamais leur couleur — tant qu'ils sont moins de
  # MEMBER_COLORS. Le rang suit l'ancienneté des comptes : l'entrée dans le foyer
  # n'est pas datée. Mémorisé par foyer pour la requête, l'en-tête de chaque page
  # le demandant.
  # @param user [User]
  # @return [Integer] de 0 à MEMBER_COLORS - 1
  def member_color(user)
    @member_ranks ||= {}
    ranks = @member_ranks[user.household_id] ||= user.household.members.order(:created_at, :id).ids
    ranks.index(user.id).to_i % MEMBER_COLORS
  end

  # Avatar d'un membre : ses initiales, dans sa couleur. Décoratif — le nom est
  # toujours écrit à côté, ou porté par le bouton qui le contient.
  # @param user [User]
  # @param css_class [String] taille et contexte de l'avatar
  def member_avatar(user, css_class)
    tag.span(user_initials(user), class: [ css_class, "member-avatar" ],
                                  data: { member_color: member_color(user) }, "aria-hidden": "true")
  end

  # Titre du bandeau de « Mon foyer » : les prénoms de ses membres.
  # @param members [Array<User>] dans l'ordre du foyer
  # @return [String] « Caroline », « Caroline & Guillaume », « Caroline, Guillaume & Léa »
  def household_title(members)
    names = members.map(&:first_name)
    return names.first.to_s if names.size < 2

    "#{names[0..-2].join(', ')} & #{names.last}"
  end

  # Ce que le foyer partage, dit sous le titre ; seul, ce qu'il partagerait.
  # @param household [Household]
  # @param usual_count [Integer] nombre de ses courses habituelles
  def household_summary(household, usual_count)
    unless household.shared?
      return "Invite quelqu'un : vous partagerez les menus, la liste de courses et les courses habituelles."
    end

    shared = [ "les menus", "la liste de courses" ]
    shared << "#{usual_count} #{usual_count > 1 ? 'courses habituelles' : 'course habituelle'}" if usual_count.positive?
    "Vous partagez #{shared.to_sentence}."
  end
end
