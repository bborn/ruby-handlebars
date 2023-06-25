require "parslet"

module Handlebars
  class Parser < Parslet::Parser
    rule(:space) { match('\s').repeat(1) }
    rule(:space?) { space.maybe }
    rule(:dot) { str(".") }
    rule(:gt) { str(">") }
    rule(:hash) { str("#") }
    rule(:slash) { str("/") }
    rule(:tilde) { str("~") }
    rule(:tilde?) { str("~").maybe }

    rule(:ocurly) { str("{") }
    rule(:ccurly) { str("}") }
    rule(:pipe) { str("|") }
    rule(:eq) { str("=") }

    rule(:docurly) { ocurly >> ocurly }
    rule(:dccurly) { ccurly >> ccurly }

    rule(:tocurly) { ocurly >> ocurly >> ocurly }
    rule(:tccurly) { ccurly >> ccurly >> ccurly }

    rule(:else_kw) { str("else") }
    rule(:as_kw) { str("as") }

    rule(:identifier) { (else_kw >> space? >> dccurly).absent? >> match['@\-a-zA-Z0-9_\?'].repeat(1) }
    rule(:directory) { (else_kw >> space? >> dccurly).absent? >> match['@\-a-zA-Z0-9_\/\?'].repeat(1) }
    rule(:path) { identifier >> (dot >> (identifier | else_kw)).repeat }

    rule(:nocurly) { match("[^{}]") }
    rule(:eof) { any.absent? }

    rule(:template_content) {
      (
        nocurly.repeat(1) | # A sequence of non-curlies
        ocurly >> nocurly | # Opening curly that doesn't start a {{}}
        ccurly | # Closing curly that is not inside a {{}}
        ocurly >> eof       # Opening curly that doesn't start a {{}} because it's the end
      ).repeat(1).as(:template_content)
    }

    rule(:unsafe_replacement) {
      docurly >>
        tilde?.as(:lstrip) >>
        space? >>
        path.as(:replaced_unsafe_item) >>
        space? >>
        tilde?.as(:rstrip) >>
        dccurly
    }
    rule(:safe_replacement) {
      tocurly >>
        tilde?.as(:lstrip) >>
        space? >>
        path.as(:replaced_safe_item) >>
        space? >>
        tilde?.as(:rstrip) >>
        tccurly
    }

    rule(:sq_string) { match("'") >> match("[^']").repeat.maybe.as(:str_content) >> match("'") }
    rule(:dq_string) { match('"') >> match('[^"]').repeat.maybe.as(:str_content) >> match('"') }
    rule(:string) { sq_string | dq_string }

    rule(:parameter) {
      (as_kw >> space? >> pipe).absent? >>
        (
          (path | string).as(:parameter_name) |
          (str("(") >> space? >> identifier.as(:safe_helper_name) >> (space? >> parameters.as(:parameters)).maybe >> space? >> str(")"))
        )
    }
    rule(:parameters) { parameter >> (space >> parameter).repeat }

    rule(:argument) { identifier.as(:key) >> space? >> eq >> space? >> parameter.as(:value) }
    rule(:arguments) { argument >> (space >> argument).repeat }

    rule(:unsafe_helper) {
      docurly >>
        tilde?.as(:lstrip) >>
        space? >>
        identifier.as(:unsafe_helper_name) >> (space? >> parameters.as(:parameters)).maybe >>
        space? >>
        tilde?.as(:rstrip) >>
        dccurly
    }
    rule(:safe_helper) {
      tocurly >>
        tilde?.as(:lstrip) >>
        space? >>
        identifier.as(:safe_helper_name) >> (space? >> parameters.as(:parameters)).maybe >>
        space? >>
        tilde?.as(:rstrip) >>
        tccurly
    }

    rule(:helper) { unsafe_helper | safe_helper }

    rule(:as_block_helper) {
      docurly >>
        tilde?.as(:lstrip_oblock) >>
        hash >>
        identifier.capture(:helper_name).as(:helper_name) >>
        space >> parameters.as(:parameters) >>
        space >> as_kw >> space >> pipe >> space? >> parameters.as(:as_parameters) >> space? >> pipe >>
        space? >>
        tilde?.as(:rstrip_oblock) >>
        dccurly >>
        scope {
          block
        } >>
        scope {
          docurly >>
            # tilde?.as(:lstrip_else) >>
            space? >>
            else_kw >>
            space? >>
            # tilde?.as(:rstrip_else) >>
            dccurly >>
            scope { block_item.repeat.as(:else_block_items) }
        }.maybe >>
        dynamic { |src, scope|
          docurly >>
            tilde?.as(:lstrip_cblock) >>
            slash >>
            str(scope.captures[:helper_name]) >>
            tilde?.as(:rstrip_cblock) >>
            dccurly
        }
    }

    rule(:block_helper) {
      docurly >>
        hash >>
        identifier.capture(:helper_name).as(:helper_name) >>
        (space >> parameters.as(:parameters)).maybe >>
        space? >>
        dccurly >>
        scope {
          block
        } >>
        scope {
          docurly >> space? >> else_kw >> space? >> dccurly >> scope { block_item.repeat.as(:else_block_items) }
        }.maybe >>
        dynamic { |src, scope|
          docurly >> slash >> str(scope.captures[:helper_name]) >> dccurly
        }
    }

    rule(:partial) {
      docurly >>
        tilde?.as(:lstrip) >>
        gt >>
        space? >>
        directory.as(:partial_name) >>
        space? >>
        arguments.as(:arguments).maybe >>
        space? >>
        tilde?.as(:rstrip) >>
        dccurly
    }

    rule(:block_item) { (template_content | unsafe_replacement | safe_replacement | helper | partial | block_helper | as_block_helper) }
    rule(:block) { block_item.repeat.as(:block_items) }

    root :block
  end
end
