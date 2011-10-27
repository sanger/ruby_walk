
# this class is used to wrap an object and don't propagate to its children
# In case different can cut or not, the cut object is not register as a walked object
# This can cause performance issue
module RubyWalk
  class Cut
    attr_reader :object
    def initialize(*object)
      @object = object
    end
  end
end
class Object
  def walk_objects(options= {}, already_walked={}, parent_and_index=nil, &block)
    if options.is_a?(Array)
      if options.size == 0
      return walk_objects({}, already_walked, parent_and_index, &block)
      else
      return walk_objects(options.first, already_walked, parent_and_index, &block).walk_objects(options[1..-1], {}, nil, &block)
      end
    end

    parent = parent_and_index && parent_and_index[0]
    # we should open the Array class, but for some reason , it doesn't work in Rails ???
    if is_a?(Array)
      max_index = size-1
      return each_with_index.map {|e, i| e.walk_objects(options, already_walked, [parent,i, max_index], &block)}.flatten
    end


    # here start the real code.
    # the code look complicated, but the problem is too
    key = _compute_walk_key
    edge_key = _compute_walk_key(parent)

    __object_walked, __edge_walked = [key, edge_key].map { |k| already_walked[k] }
    object_walked = ( __object_walked == true)
    object_cut = __object_walked == RubyWalk::Cut
    process_edge = (block and block.arity > 1)
    edge_walked = (__edge_walked or not process_edge)



    # we need to process it if the edge has been done
    if object_walked and edge_walked
      #everything needed has already been done
      return []
    end
    already_walked[edge_key] = true if process_edge

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
    case self_object
    when RubyWalk::Cut
      # no propagation
      if object_walked or (object_cut and edge_walked)
        []
      else
        #we return the real object, and mark it as already cut
        already_walked[key] = RubyWalk::Cut
        [self_object.object]
      end
    when nil
      return []
    else
      #standard case
      already_walked[key] = true
      if object_walked 
        [self_object]
      else
      (_walk_objects(options, already_walked, parent_and_index, &block ). << self_object).flatten
      end
    end
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
  def _compute_walk_key(parent=nil)
    parent ? [object_id, parent._compute_walk_key]  : object_id
  end

end

if defined?(ActiveRecord)
  class ActiveRecord::Base
    def _compute_walk_key(parent=nil)
      # the id of the object doesn't work,
      # because an active record can be loaded many times into different object
      # so we have to use ActiveRecord#id (and class)
      key = [self.class.name, self.id, parent ? parent._compute_walk_key : nil].compact
    end

  end

  class ActiveRecord::Associations::AssociationProxy
    delegate :_compute_walk_key, :to => :target
  end
end
