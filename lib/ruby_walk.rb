
# this class is used to wrap an object and don't propagate to its children
# In case different can cut or not, the cut object is not register as a walked object
# This can cause performance issue
class Cut
  attr_reader :object
  def initialize(*object)
    @object = object
  end
end
class Object
  def walk_objects(options= {}, already_walked={}, parent_and_index=nil, &block)
    if options.is_a?(Array)
      if options.size == 0
      return walk_objects({}, already_walked, parent_and_index, &block)
      else
      return walk_objects(options.first, already_walked, parent_and_index, &block).walk_objects(options[1..-1], already_walked, parent_and_index, &block)
      end
    end

    # we should open the Array class, but for some reason , it doesn't work in Rails ???
    if is_a?(Array)
      parent = parent_and_index && parent_and_index[0]
      max_index = size-1
      return each_with_index.map {|e, i| e.walk_objects(options, already_walked, [parent,i, max_index], &block)}.flatten
    end

    # we compute a key to store if an object has already been loaded or not.can be the idea for transiant object
    key = _compute_walk_key
    #puts "walking #{key.inspect}"
    return [] if already_walked[key] == true

    #we skip object which the block has return nil
    #but we propagate those which return []
    
    self_object = if block 
                    case block.arity
                    when 1 then block[self] 
                    when 2 then block[self,parent_and_index[0]]
                    when 3 then block[self, *parent_and_index[0,3]] # parent + index
                    when 4 then block[self, *parent_and_index[0,4]] # parent + index + max_index
                    else raise RuntimeError, "wrong number of argument"
                    end
                  else
                    self
                  end
    # Hack to be able to process cut object only once, but do them properly if needed
    # TODO do it better
    if self_object.is_a?(Cut)
      return [] if  already_walked[key]== Cut

      already_walked[key] = Cut
      return self_object.object
    end
    return [] if self_object.nil?
    already_walked[key] = true

    (_walk_objects(options, already_walked, parent_and_index, &block ). << self_object).flatten
  end


  private
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

  def _walk_objects(options, already_walked={}, parent_and_index=nil, &block)
    walked = []
    to_walk = _find_methods_to_walk(options)
    max_index =to_walk
    to_walk.each_with_index do |action, index|
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
        end.walk_objects(options, already_walked, [self, nil, nil], &block)
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
