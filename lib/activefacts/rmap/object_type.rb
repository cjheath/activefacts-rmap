require 'activefacts/support'

module ActiveFacts
  module API
    module ObjectType
      def table
        @is_table = true
      end

      def is_table
        @is_table
      end

      def columns
raise "This method is no longer in use"
=begin
        return @columns if @columns
        trace :rmap, "Calculating columns for #{basename}" do
          @columns = (
            if superclass.is_entity_type
              # REVISIT: Need keys to secondary supertypes as well, but no duplicates.
              trace :rmap, "Separate subtype has a foreign key to its supertype" do
                superclass.__absorb([[superclass.basename]], self)
              end
            else
              []
            end +
            # Then absorb all normal roles:
            roles.values.select do |role|
              role.unique && !role.counterpart_unary_has_precedence
            end.inject([]) do |columns, role|
              rn = role.name.to_s.split(/_/)
              trace :rmap, "Role #{rn*'.'}" do
                columns += role.counterpart_object_type.__absorb([rn], role.counterpart)
              end
            end +
            # And finally all absorbed subtypes:
            subtypes.
              select{|subtype| !subtype.is_table}.    # Don't absorb separate subtypes
              inject([]) do |columns, subtype|
                # Pass self as 2nd param here, not a role, standing for the supertype role
                subtype_name = subtype.basename
                trace :rmap, "Absorbing subtype #{subtype_name}" do
                  columns += subtype.__absorb([[subtype_name]], self)
                end
              end
            ).map do |col_names|
              last = nil
              col_names.flatten.map do |name|
                name.downcase.sub(/^[a-z]/){|c| c.upcase}
              end.
              reject do |n|
                # Remove sequential duplicates:
                dup = last == n
                last = n
                dup
              end*"."
            end
        end
=end
      end

      # Return an array of the absorbed columns, using prefix for name truncation
      def __absorb(prefix, except_role = nil)
        # also considered a table if the superclass isn't excluded and is (transitively) a table
        if !@is_table && (except_role == superclass || !is_table_subtype)
          if is_entity_type
            if (role = fully_absorbed) && role != except_role
              # If this non-table is fully absorbed into another table (not our caller!)
              # (another table plays its single identifying role), then absorb that role only.
              # counterpart_object_type = role.counterpart_object_type
              # This omission matches the one in columns.rb, see EntityType#reference_columns
              # new_prefix = prefix + [role.name.to_s.split(/_/)]
              trace :rmap, "Reference to #{role.name} (absorbed elsewhere)" do
                role.counterpart_object_type.__absorb(prefix, role.counterpart)
              end
            else
              # Not a table -> all roles are absorbed
              roles.
                  values.
                  select do |role|
                    role.unique && role != except_role && !role.counterpart_unary_has_precedence
                  end.
                  inject([]) do |columns, role|
                columns += __absorb_role(prefix, role)
              end +
              subtypes.          # Absorb subtype roles too!
                select{|subtype| !subtype.is_table}.    # Don't absorb separate subtypes
                inject([]) do |columns, subtype|
                  # Pass self as 2nd param here, not a role, standing for the supertype role
                  new_prefix = prefix[0..-2] + [[subtype.basename]]
                  trace :rmap, "Absorbed subtype #{subtype.basename}" do
                    columns += subtype.__absorb(new_prefix, self)
                  end
                end
            end
          else
            [prefix]
          end
        else
          # Create a foreign key to the table
          if is_entity_type
            ir = identifying_role_names.map{|role_name| roles(role_name) }
            trace :rmap, "Reference to #{basename} with #{prefix.inspect}" do
              ic = identifying_role_names.map{|role_name| role_name.to_s.split(/_/)}
              ir.inject([]) do |columns, role|
                columns += __absorb_role(prefix, role)
              end
            end
          else
            # Reference to value type which is a table
            col = prefix.clone
            trace :rmap, "Self-value #{col[-1]}.Value"
            col[-1] += ["Value"]
            col
          end
        end
      end

      def __absorb_role(prefix, role)
        if prefix.size > 0 and
            (c = role.owner).is_entity_type and
            c.identifying_roles == [role] and
            (irn = c.identifying_role_names).size == 1 and
            (n = irn[0].to_s.split(/_/)).size > 1 and
            (owner = role.owner.basename.snakecase.split(/_/)) and
            n[0...owner.size] == owner
          trace :rmap, "truncating transitive identifying role #{n.inspect}"
          owner.size.times { n.shift }
          new_prefix = prefix + [n]
        elsif (c = role.counterpart_object_type).is_entity_type and
            (irn = c.identifying_role_names).size == 1 and
            #irn[0].to_s.split(/_/)[0] == role.owner.basename.downcase
            irn[0] == role.counterpart.name
          #trace :rmap, "=== #{irn[0].to_s.split(/_/)[0]} elided ==="
          new_prefix = prefix
        elsif (fa_role = fully_absorbed) && fa_role == role
          new_prefix = prefix
        else
          new_prefix = prefix + [role.name.to_s.split(/_/)]
        end
        #trace :rmap, "new_prefix is #{new_prefix*"."}"

        trace :rmap, "Absorbing role #{role.name} as #{new_prefix[prefix.size..-1]*"."}" do
          role.counterpart_object_type.__absorb(new_prefix, role.counterpart)
        end
      end

      def is_table_subtype
        return true if is_table
        klass = superclass
        while klass.is_entity_type
          return true if klass.is_table
          klass = klass.superclass
        end
        return false
      end
    end

    module Entity
      module ClassMethods
        def fully_absorbed
          return false unless (ir = identifying_role_names) && ir.size == 1
          role = roles(ir[0])
          return role if ((cp = role.counterpart_object_type).is_table ||
              (cp.is_entity_type && cp.fully_absorbed))
          return superclass if superclass.is_entity_type  # Absorbed subtype
          nil
        end
      end
    end

    # A one-to-one can be absorbed into either table. We decide which by comparing
    # the names, just as happens in ObjectType.populate_reference (see reference.rb)
    class Role
      def counterpart_unary_has_precedence
        counterpart_object_type.is_table_subtype and
          counterpart.unique and
          owner.name.downcase < counterpart.owner.name.downcase
      end
    end

  end
end

class TrueClass
  def self.__absorb(prefix, except_role = nil)
    [prefix]
  end

  def self.is_table
    false
  end

  def self.is_table_subtype
    false
  end
end
