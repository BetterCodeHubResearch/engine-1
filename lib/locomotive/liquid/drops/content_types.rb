module Locomotive
  module Liquid
    module Drops
      class ContentTypes < ::Liquid::Drop

        def before_method(meth)
          type = @context.registers[:site].content_types.where(slug: meth.to_s).first
          ContentTypeProxyCollection.new(type)
        end

      end

      class ContentTypeProxyCollection < ProxyCollection

        def initialize(content_type)
          @content_type = content_type
          @collection   = nil
        end

        def public_submission_url
          @context.registers[:controller].main_app.locomotive_entry_submissions_url(@content_type.slug)
        end

        def api
          Locomotive.log :warn, "[Liquid template] the api for content_types has been deprecated and replaced by public_submission_url instead."
          { 'create' => public_submission_url }
        end

        def before_method(meth)
          klass = @content_type.entries.klass # delegate to the proxy class

          if (meth.to_s =~ /^group_by_(.+)$/) == 0
            klass.send(:group_by_select_option, $1, @content_type.order_by_definition)
          elsif (meth.to_s =~ /^(.+)_options$/) == 0
            klass.send(:"#{$1}_options").map { |option| option['name'] }
          else
            Locomotive.log :warn, "[Liquid template] trying to call #{meth} on a content_type object"
          end
        end

        protected

        def collection
          if @context['with_scope']
            self.modify_with_scope_with_relations
          end

          @collection ||= @content_type.ordered_entries(@context['with_scope']).visible
        end

        def modify_with_scope_with_relations
          relations = @content_type.klass_with_custom_fields(:entries).relations
          @context['with_scope'].dup.each do |key, value|
            if relation = self.relation_with(key, relations)
              model = Locomotive::ContentType.class_name_to_content_type(relation.class_name, @context.registers[:site])
              entry = model.entries.where(model.label_field_name => value).first

              @context['with_scope'].delete(key)
              @context['with_scope'][relation.key] = entry
            end
          end
        end

        def relation_with(name, relations)
          if relations.keys.include?(name.to_s)
            relations[name]
          elsif relations.keys.include?(name.to_s.pluralize)
            relations[name.to_s.pluralize]
          end
        end
      end

    end
  end
end
