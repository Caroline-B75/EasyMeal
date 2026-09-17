# frozen_string_literal: true

# Le foyer : les comptes qui partagent les mêmes menus et la même liste de courses.
#
# Les menus quittent le compte pour le foyer. Chaque compte existant reçoit son
# propre foyer, d'une seule personne, et y retrouve tous ses menus : rien ne
# change pour lui tant qu'il n'invite personne.
#
# Les deux règles « un seul menu actif » et « un seul brouillon » suivent les
# menus : elles portent désormais sur le foyer.
class CreateHouseholds < ActiveRecord::Migration[8.1]
  def up
    create_table :households do |t|
      t.string :invite_token, null: false
      t.timestamps
    end
    add_index :households, :invite_token, unique: true

    add_reference :users, :household, foreign_key: true
    # Pas d'index simple : l'index composite (household_id, status) le couvre.
    add_reference :menus, :household, foreign_key: true, index: false

    give_each_user_a_household

    change_column_null :users, :household_id, false
    change_column_null :menus, :household_id, false
    add_index :menus, [ :household_id, :status ]
    add_index :menus, :household_id, unique: true, where: "status = 1",
                                     name: "index_menus_on_household_id_unique_active"
    add_index :menus, :household_id, unique: true, where: "status = 0",
                                     name: "index_menus_on_household_id_unique_draft"

    # Retirer la colonne emporte avec elle tous les index qui la contiennent,
    # dont les deux contraintes d'unicité par compte.
    remove_reference :menus, :user, foreign_key: true, index: true
  end

  # Un foyer ne sait pas qui a composé chacun de ses menus : ils reviennent tous
  # à son plus ancien membre. Un foyer n'ayant qu'un menu actif et qu'un
  # brouillon, les contraintes d'unicité par compte tiennent.
  def down
    add_reference :menus, :user, foreign_key: true
    execute(<<~SQL.squish)
      UPDATE menus
         SET user_id = (SELECT MIN(users.id) FROM users WHERE users.household_id = menus.household_id)
    SQL
    change_column_null :menus, :user_id, false
    add_index :menus, [ :user_id, :status ]
    add_index :menus, [ :user_id, :start_date ]
    add_index :menus, :user_id, unique: true, where: "status = 1", name: "index_menus_on_user_id_unique_active"
    add_index :menus, :user_id, unique: true, where: "status = 0", name: "index_menus_on_user_id_unique_draft"

    remove_reference :menus, :household, foreign_key: true, index: false
    remove_reference :users, :household, foreign_key: true, index: true
    drop_table :households
  end

  private

  # Un foyer par compte, qui reçoit ses menus. Le jeton d'invitation est tiré
  # comme le fera has_secure_token (SecureRandom) : il doit être impossible à
  # deviner, ce que ni random() ni md5() de PostgreSQL ne garantissent.
  #
  # Messages coupés : la migration journalise chaque requête, et les jetons —
  # qui ouvrent l'accès à un foyer — finiraient en clair dans les logs de
  # déploiement.
  def give_each_user_a_household
    say_with_time "Un foyer pour chaque compte existant" do
      suppress_messages do
        select_values("SELECT id FROM users ORDER BY id").each do |user_id|
          household_id = insert(<<~SQL.squish)
            INSERT INTO households (invite_token, created_at, updated_at)
            VALUES (#{quote(SecureRandom.base58(24))}, NOW(), NOW())
          SQL

          execute("UPDATE users SET household_id = #{Integer(household_id)} WHERE id = #{Integer(user_id)}")
          execute("UPDATE menus SET household_id = #{Integer(household_id)} WHERE user_id = #{Integer(user_id)}")
        end
      end
    end
  end
end
