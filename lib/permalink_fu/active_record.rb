module PermalinkFu

  module ActiveRecord

    def self.included(base)
      base.extend(ClassMethods)
    end

    # This is the plugin method available on all ActiveRecord models.
    module ClassMethods
      # Specifies the given field(s) as a permalink, meaning it is passed through PermalinkFu.escape and set to the permalink_field.  This
      # is done
      #
      #   class Foo < ActiveRecord::Base
      #     # stores permalink form of #title to the #permalink attribute
      #     has_permalink :title
      #
      #     # stores a permalink form of "#{category}-#{title}" to the #permalink attribute
      #
      #     has_permalink [:category, :title]
      #
      #     # stores permalink form of #title to the #category_permalink attribute
      #     has_permalink [:category, :title], :category_permalink
      #
      #     # add a scope
      #     has_permalink :title, :scope => :blog_id
      #
      #     # add a scope and specify the permalink field name
      #     has_permalink :title, :slug, :scope => :blog_id
      #
      #     # do not bother checking for a unique scope
      #     has_permalink :title, :unique => false
      #
      #     # update the permalink every time the attribute(s) change
      #     # without _changed? methods (old rails version) this will rewrite the permalink every time
      #     has_permalink :title, :update => true
      #
      #   end
      #
      def has_permalink(attr_names = [], permalink_field = nil, options = {})
        include InstanceMethods

        if permalink_field.is_a?(Hash)
          options = permalink_field
          permalink_field = nil
        end


        cattr_accessor :permalink_options
        cattr_accessor :permalink_attributes
        cattr_accessor :permalink_field

        self.permalink_attributes = Array(attr_names)
        self.permalink_field      = (permalink_field || 'permalink').to_s
        self.permalink_options    = {:unique => true}.update(options)

        if self.permalink_options[:unique]
          before_validation :create_unique_permalink
        else
          before_validation :create_common_permalink
        end

        define_method :"#{self.permalink_field}=" do |value|
          write_attribute(self.permalink_field, value.blank? ? '' : PermalinkFu.escape(value))
        end

      end
    end

    # This contains instance methods for ActiveRecord models that have permalinks.
    module InstanceMethods

      protected

      def create_common_permalink
        return unless should_create_permalink?
        if read_attribute(self.class.permalink_field).blank? || permalink_fields_changed?
          send("#{self.class.permalink_field}=", create_permalink_for(self.class.permalink_attributes))
        end

        # Quit now if we have the changed method available and nothing has changed
        permalink_changed = "#{self.class.permalink_field}_changed?"
        return if respond_to?(permalink_changed) && !send(permalink_changed)

        # Otherwise find the limit and crop the permalink
        limit   = self.class.columns_hash[self.class.permalink_field].limit
        base    = send("#{self.class.permalink_field}=", read_attribute(self.class.permalink_field)[0..limit - 1])
        [limit, base]
      end

      def create_unique_permalink
        limit, base = create_common_permalink
        return if limit.nil? # nil if the permalink has not changed or :if/:unless fail
        counter = 1
        # oh how i wish i could use a hash for conditions
        conditions = ["#{self.class.permalink_field} = ?", base]
        unless new_record?
          conditions.first << " and id != ?"
          conditions       << id
        end
        if self.class.permalink_options[:scope]
          [self.class.permalink_options[:scope]].flatten.each do |scope|
            value = send(scope)
            if value
              conditions.first << " and #{self.class.table_name}.#{scope} = ?"
              conditions       << send(scope)
            else
              conditions.first << " and #{self.class.table_name}.#{scope} IS NULL"
            end
          end
        end

        while ::ActiveRecord::Base.uncached{self.class.exists?(conditions)}
          suffix = "-#{counter += 1}"
          conditions[1] = "#{base[0..limit-suffix.size-1]}#{suffix}"
          send("#{self.class.permalink_field}=", conditions[1])
        end
      end

      def create_permalink_for(attr_names)
        str = attr_names.collect { |attr_name| send(attr_name).to_s } * " "
        str.blank? ? PermalinkFu.random_permalink : str
      end

      private
      def should_create_permalink?
        if self.class.permalink_field.blank?
          false
        elsif self.class.permalink_options[:if]
          evaluate_method(self.class.permalink_options[:if])
        elsif self.class.permalink_options[:unless]
          !evaluate_method(self.class.permalink_options[:unless])
        else
          true
        end
      end

      # Don't even check _changed? methods unless :update is set
      def permalink_fields_changed?
        return false unless self.class.permalink_options[:update]
        self.class.permalink_attributes.any? do |attribute|
          changed_method = "#{attribute}_changed?"
          respond_to?(changed_method) ? send(changed_method) : true
        end
      end

      def evaluate_method(method)
        case method
        when Symbol
          send(method)
        when String
          eval(method, instance_eval { binding })
        when Proc, Method
          method.call(self)
        end
      end
    end
  end

end