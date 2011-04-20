class Object
  def walk_objects(options= {}, already_walked={}, &block)
    if options.is_a?(Array)
      if options.size == 0
      return walk_objects({}, already_walked, &block)
      else
      return walk_objects(options.first, already_walked, &block).walk_objects(options[1..-1], already_walked, &block)
      end
    end

    # we should open the Array class, but for some reason , it doesn't work in Rails ???
    return map {|e| e.walk_objects(options, already_walked,&block)}.flatten if is_a?(Array)

    # we compute a key to store if an object has already been loaded or not.can be the idea for transiant object
    key = _compute_walk_key
    return [] if already_walked.include?(key)
    already_walked[key] = true

    #we skip object which the block has return nil
    #but we propagate those which return []
    self_object = block ? block[self] : self
    return [] if self_object.nil?

    (_walk_objects(options, already_walked, &block ). << self_object).flatten
  end


  #private
  def _default_methods_to_walk()
    []
  end
  def _find_methods_to_walk(options)
    _find_methods_to_walk_for_class(self.class, options).uniq
  end

  def _find_methods_to_walk_for_class(klass,options)
    methods = options[klass] || options[klass.name.downcase] || options[klass.name.downcase.to_sym] || _default_methods_to_walk()
    methods = [methods].flatten # create a new list
    if !methods.delete(:skip_super) && klass.superclass
      methods.concat(_find_methods_to_walk_for_class(klass.superclass, options))
    end
    methods

  end

  def _walk_objects(options, already_walked, &block)
    walked = []
    _find_methods_to_walk(options).each do |action|
      walked += case action
        when Proc
          case action.arity
          when 1
            action.call(self, &block)
          else
            action.call(&block)
          end
        when Symbol
          self.send(action)
        else 
          []
        end.walk_objects(options, already_walked, &block)
    end
    walked
  end
  def _compute_walk_key()
    object_id
  end

end

if defined?(ActiveRecord)
  class ActiveRecord::Base
    def _compute_walk_key()
      # the idea of the object doesn't work, because an active record can be loaded many times into different object
      key = [self.class.name, self.id]
    end

  end

  class ActiveRecord::Associations::AssociationProxy
    delegate :_compute_walk_key, :to => :target
  end
end
