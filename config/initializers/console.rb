if defined?(Rails::Console)
  require 'awesome_print'
  AwesomePrint.irb!
  
  AwesomePrint.defaults = {
    indent: 4, # Augmente l'indentation pour plus de lisibilité
    multiline: true,
    sort_keys: true,
    limit: false, # Désactive la limite pour afficher tous les éléments
    color: {
      array: :cyan,
      hash: :yellowish,
      string: :green
    }
  }
  
  begin
    require 'table_print'
  rescue LoadError
  end
end