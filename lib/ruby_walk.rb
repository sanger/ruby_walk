
class Object
  def walk_objects(options= {}, already_walked={}, &block)
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


  private
    def find_methods_to_walk(options)
      options[self.class] or options[self.class.name.downcase] or options[self.class.name.downcase.to_sym] or (defined?(super)? super(options) : [])
    end

  def _walk_objects(options, already_walked={})
    walked = []
    find_methods_to_walk(options).each do |action|
      walked += case action
        when Proc
          case action.arity
          when 1
            action.call(self, &block)
          else
            action.call(&block)
          end
        when Symbol
          self.send(action).walk_objects(options, already_walked, &block)
        else 
          []
        end
    end
    walked
  end
  def _compute_walk_key()
    object_id
  end

end

class Array
  def walk_objects(options, already_walked={}, &block)
    map {|e| e.walk_objects(options, already_walked,&block)}.flatten
  end
end

begin

#TODO test if ActiveRecord exists or not
class ActiveRecord
  def _compute_walk_key()
    # the idea of the object doesn't work, because an active record can be loaded many times into different object
    key = [self.class.name, self.id]
  end

end

end
