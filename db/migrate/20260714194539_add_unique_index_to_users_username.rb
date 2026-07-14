class AddUniqueIndexToUsersUsername < ActiveRecord::Migration[7.2]
  def change
    # Unicité du username garantie au niveau base (au-delà de la validation
    # modèle) pour empêcher tout doublon, y compris en cas d'inscriptions
    # concurrentes. Le username identifie l'auteur des commentaires.
    add_index :users, :username, unique: true
  end
end
