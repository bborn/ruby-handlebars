module Handlebars
  module Tree
    class TreeItem < Struct
      def eval(context)
        _eval(context)
      end
    end

    class TemplateContent < TreeItem.new(:content)
      def _eval(context)
        content
      end
    end

    class Replacement < TreeItem.new(:item, :lstrip, :rstrip)
      def _eval(context)
        output = if context.get_helper(item.to_s).nil?
          context.get(item.to_s)
        else
          context.get_helper(item.to_s).apply(context)
        end

        if lstrip
          output = output.lstrip
        end
        if rstrip
          output = output.rstrip
        end

        output
      end
    end

    class EscapedReplacement < Replacement
      def _eval(context)
        context.escaper.escape(super(context).to_s)
      end
    end

    class String < TreeItem.new(:content)
      def _eval(context)
        content
      end
    end

    class Parameter < TreeItem.new(:name)
      def _eval(context)
        if name.is_a?(Parslet::Slice)
          context.get(name.to_s)
        else
          name._eval(context)
        end
      end
    end

    class Helper < TreeItem.new(:name, :parameters, :block, :else_block, :lstrip, :rstrip)
      def _eval(context)
        helper = context.get_helper(name.to_s)
        if helper.nil?
          context.get_helper("helperMissing").apply(context, String.new(name.to_s))
        else
          helper.apply(context, parameters, block, else_block)
        end
      end
    end

    class AsHelper < TreeItem.new(:name, :parameters, :as_parameters, :block, :else_block, :lstrip_oblock, :rstrip_oblock, :lstrip_cblock, :rstrip_cblock, :lstrip_else, :rstrip_else)
      def _eval(context)
        helper = context.get_as_helper(name.to_s)
        if helper.nil?
          context.get_helper("helperMissing").apply(context, String.new(name.to_s))
        else
          helper.apply_as(context, parameters, as_parameters, block, else_block)
        end
      end
    end

    class EscapedHelper < Helper
      def _eval(context)
        context.escaper.escape(super(context).to_s)
      end
    end

    class Partial < TreeItem.new(:partial_name, :lstrip, :rstrip)
      def _eval(context)
        output = context.get_partial(partial_name.to_s).call_with_context(context)
        if lstrip
          output = output.lstrip
        end
        if rstrip
          output = output.rstrip
        end
        output
      end
    end

    class PartialWithArgs < TreeItem.new(:partial_name, :arguments, :lstrip, :rstrip)
      def _eval(context)
        [arguments].flatten.map(&:values).map do |vals|
          context.add_item vals.first.to_s, vals.last._eval(context)
        end
        output = context.get_partial(partial_name.to_s).call_with_context(context)
        if lstrip
          output = output.lstrip
        end
        if rstrip
          output = output.rstrip
        end
        output
      end
    end

    class Block < TreeItem.new(:items)
      def _eval(context)
        items.map { |item| item._eval(context) }.join
      end
      alias_method :fn, :_eval

      def add_item(i)
        items << i
      end
    end
  end

  class Transform < Parslet::Transform
    rule(template_content: simple(:content)) { Tree::TemplateContent.new(content) }
    rule(
      replaced_unsafe_item: simple(:item),
      lstrip: simple(:lstrip),
      rstrip: simple(:rstrip)
    ) {
      Tree::EscapedReplacement.new(item, lstrip, rstrip)
    }

    rule(
      replaced_unsafe_item: simple(:item),
      lstrip: simple(:lstrip),
      rstrip: simple(:rstrip)
    ) {
      Tree::EscapedReplacement.new(item, lstrip, rstrip)
    }

    rule(
      replaced_safe_item: simple(:item),
      lstrip: simple(:lstrip),
      rstrip: simple(:rstrip)
    ) {
      Tree::Replacement.new(item, lstrip, rstrip)
    }
    rule(str_content: simple(:content)) { Tree::String.new(content) }
    rule(parameter_name: simple(:name)) { Tree::Parameter.new(name) }

    rule(
      unsafe_helper_name: simple(:name),
      parameters: subtree(:parameters),
      lstrip: simple(:lstrip),
      rstrip: simple(:rstrip)
    ) {
      Tree::EscapedHelper.new(name, parameters, nil, nil, lstrip, rstrip)
    }
    rule(
      unsafe_helper_name: simple(:name),
      parameters: subtree(:parameters)
    ) {
      Tree::EscapedHelper.new(name, parameters, nil, nil, nil, nil)
    }

    rule(
      safe_helper_name: simple(:name),
      parameters: subtree(:parameters),
      lstrip: simple(:lstrip),
      rstrip: simple(:rstrip)
    ) {
      Tree::Helper.new(name, parameters, nil, nil, lstrip, rstrip)
    }
    rule(
      safe_helper_name: simple(:name),
      parameters: subtree(:parameters)
    ) {
      Tree::Helper.new(name, parameters, nil, nil, nil, nil)
    }

    rule(
      helper_name: simple(:name),
      block_items: subtree(:block_items)
    ) {
      Tree::Helper.new(name, [], block_items)
    }

    rule(
      helper_name: simple(:name),
      block_items: subtree(:block_items),
      else_block_items: subtree(:else_block_items)
    ) {
      Tree::Helper.new(name, [], block_items, else_block_items)
    }

    rule(
      helper_name: simple(:name),
      parameters: subtree(:parameters),
      block_items: subtree(:block_items)
    ) {
      Tree::Helper.new(name, parameters, block_items)
    }

    rule(
      helper_name: simple(:name),
      parameters: subtree(:parameters),
      block_items: subtree(:block_items),
      else_block_items: subtree(:else_block_items),
      lstrip_oblock: simple(:lstrip_oblock),
      rstrip_oblock: simple(:rstrip_oblock),
      lstrip_cblock: simple(:lstrip_cblock),
      rstrip_cblock: simple(:rstrip_cblock),
      lstrip_else: simple(:lstrip_else),
      rstrip_else: simple(:rstrip_else)
    ) {
      Tree::Helper.new(
        name, parameters, block_items, else_block_items,
        lstrip_oblock, rstrip_oblock, lstrip_cblock,
        rstrip_cblock, lstrip_else, rstrip_else
      )
    }

    rule(
      helper_name: simple(:name),
      parameters: subtree(:parameters),
      as_parameters: subtree(:as_parameters),
      block_items: subtree(:block_items),
      lstrip_oblock: simple(:lstrip_oblock),
      rstrip_oblock: simple(:rstrip_oblock),
      lstrip_cblock: simple(:lstrip_cblock),
      rstrip_cblock: simple(:rstrip_cblock)
    ) {
      Tree::AsHelper.new(
        name, parameters, as_parameters, block_items, nil, lstrip_oblock, rstrip_oblock, lstrip_cblock, rstrip_cblock
      )
    }

    rule(
      helper_name: simple(:name),
      parameters: subtree(:parameters),
      as_parameters: subtree(:as_parameters),
      block_items: subtree(:block_items),
      else_block_items: subtree(:else_block_items),
      lstrip_oblock: simple(:lstrip_oblock),
      rstrip_cblock: simple(:rstrip_cblock),
      lstrip_else: simple(:lstrip_else),
      rstrip_else: simple(:rstrip_else)
    ) {
      raise "here"
      Tree::AsHelper.new(name, parameters, as_parameters, block_items, else_block_items, lstrip_oblock, rstrip_cblock, lstrip_else, rstrip_else)
    }

    rule(
      partial_name: simple(:partial_name),
      arguments: subtree(:arguments),
      lstrip: simple(:lstrip),
      rstrip: simple(:rstrip)
    ) {
      Tree::PartialWithArgs.new(partial_name, arguments, lstrip, rstrip)
    }

    rule(
      partial_name: simple(:partial_name),
      lstrip: simple(:lstrip),
      rstrip: simple(:rstrip)
    ) {
      Tree::Partial.new(partial_name, lstrip, rstrip)
    }

    rule(block_items: subtree(:block_items)) { Tree::Block.new(block_items) }

    rule(
      else_block_items: subtree(:else_block_items)
    ) { Tree::Block.new(block_items) }
  end
end
