module DataMapper
  module NestedAttributes
    
    module Resource
      
      # This method can be used to remove ambiguities from the passed attributes.
      # Consider a situation with a belongs_to association where both a valid value
      # for the foreign_key attribute *and* nested_attributes for a new record are
      # present (i.e. item_type_id and item_type_attributes are present).
      # Also see http://is.gd/sz2d on the rails-core ml for a discussion on this.
      # The basic idea is, that there should be a well defined behavior for what
      # exactly happens when such a situation occurs. I'm currently in favor for 
      # using the foreign_key if it is present, but this probably needs more thinking.
      # For now, this method basically is a no-op, but at least it provides a hook where
      # everyone can perform it's own sanitization (just overwrite this method) 
      def sanitize_nested_attributes(attrs)
        attrs # noop
      end
      
      private

      # Attribute hash keys that should not be assigned as normal attributes.
      # These hash keys are nested attributes implementation details.
      UNASSIGNABLE_KEYS = [ :id, :_delete ]
    
    
      # Assigns the given attributes to the association.
      #
      # If the given attributes include an <tt>:id</tt> that matches the existing
      # record’s id, then the existing record will be modified. Otherwise a new
      # record will be built.
      #
      # If the given attributes include a matching <tt>:id</tt> attribute _and_ a
      # <tt>:_delete</tt> key set to a truthy value, then the existing record
      # will be marked for destruction.
      def assign_nested_attributes_for_relationship_to_resource(relationship, attributes)
        if attributes[:id].blank?
          unless reject_new_record?(relationship, attributes)
            relationship.set(self, relationship.target_model.new(attributes.except(*UNASSIGNABLE_KEYS)))
          end
        else
          existing_record = relationship.get(self)
          if existing_record && existing_record.id.to_s == attributes[:id].to_s
            assign_to_or_mark_for_destruction(relationship, existing_record, attributes)
          end
        end
      end
    
      # Assigns the given attributes to the collection association.
      #
      # Hashes with an <tt>:id</tt> value matching an existing associated record
      # will update that record. Hashes without an <tt>:id</tt> value will build
      # a new record for the association. Hashes with a matching <tt>:id</tt>
      # value and a <tt>:_delete</tt> key set to a truthy value will mark the
      # matched record for destruction.
      #
      # For example:
      #
      # assign_nested_attributes_for_collection_association(:people, {
      # '1' => { :id => '1', :name => 'Peter' },
      # '2' => { :name => 'John' },
      # '3' => { :id => '2', :_delete => true }
      # })
      #
      # Will update the name of the Person with ID 1, build a new associated
      # person with the name `John', and mark the associatied Person with ID 2
      # for destruction.
      #
      # Also accepts an Array of attribute hashes:
      #
      # assign_nested_attributes_for_collection_association(:people, [
      # { :id => '1', :name => 'Peter' },
      # { :name => 'John' },
      # { :id => '2', :_delete => true }
      # ])
      def assign_nested_attributes_for_relationship_to_collection(relationship, attributes_collection)
      
        normalize_attributes_collection(attributes_collection).each do |attributes|
          
          if attributes[:id].blank?
            next if reject_new_record?(relationship, attributes)
            relationship.get(self).new(attributes.except(*UNASSIGNABLE_KEYS))
          else
            collection = relationship.get(self)
            if existing_record = collection.detect { |record| record.id.to_s == attributes[:id].to_s }
              assign_to_or_mark_for_destruction(relationship, existing_record, attributes)
            end
          end
          
        end
      
      end
    
      # Updates a record with the +attributes+ or marks it for destruction if
      # +allow_destroy+ is +true+ and has_delete_flag? returns +true+.
      def assign_to_or_mark_for_destruction(relationship, resource, attributes)
        allow_destroy = self.class.options_for_nested_attributes[relationship][:allow_destroy]
        if has_delete_flag?(attributes) && allow_destroy
          resource.mark_for_destruction
        else
          resource.update(attributes.except(*UNASSIGNABLE_KEYS))
        end
      end
    
      # Determines if a hash contains a truthy _delete key.
      def has_delete_flag?(hash)
        # TODO find out if this activerecord code needs to be ported
        # ConnectionAdapters::Column.value_to_boolean hash['_delete']
        hash[:_delete]
      end
    
      # Determines if a new record should be build by checking for
      # has_delete_flag? or if a <tt>:reject_if</tt> proc exists for this
      # association and evaluates to +true+.
      def reject_new_record?(relationship, attributes)
        guard = self.class.options_for_nested_attributes[relationship][:reject_if]
        has_delete_flag?(attributes) || !evaluate_reject_new_record_guard(guard, attributes)
      end
      
      def evaluate_reject_new_record_guard(guard, attributes)
        return true if guard.nil?
        (guard.is_a?(Symbol) || guard.is_a?(String)) ? send(guard) : guard.call(attributes)
      end
      
      def normalize_attributes_collection(attributes_collection)
        if attributes_collection.is_a?(Hash)
          attributes_collection.sort_by { |index, _| index.to_i }.map { |_, attributes| attributes }
        else
          attributes_collection
        end
      end
      
    end
    
    module CommonResourceSupport

      # remove mark for destruction if present
      # before delegating reload behavior to super
      def reload
        @marked_for_destruction = false
        super
      end

      def marked_for_destruction?
        @marked_for_destruction
      end

      def mark_for_destruction
        @marked_for_destruction = true
      end

    end

  end
end
