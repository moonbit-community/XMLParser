///|
typealias Context[T] = (T?, XMLParserContext)

///| 在解析时只维护index, line_number和column_number暂时只在最后更新
pub struct XMLParserContext {
  ///|
  input_array : Array[Char]
  ///| the current position in the input sequence(start from 0)
  index : Int

  ///|
  mut line_number : Int
  mut column_number : Int
  errors : Array[XMLParseError]
  warnings : Array[String]
} derive(Show)

///|
fn new_context(s : String) -> XMLParserContext {
  {
    input_array: s.to_array(),
    index: 0,
    line_number: 0,
    column_number: 0,
    errors: [],
    warnings: [],
  }
}

// 更新位置信息
///|
fn update_location(
  ctx : XMLParserContext,
  start~ : Int = 0,
  end~ : Int = ctx.index
) -> XMLParserContext {
  let text = ctx.input_array[start:end]
  ctx.line_number = 1
  ctx.column_number = 0
  text.each(fn(c) {
    if c == '\n' {
      ctx.line_number += 1
      ctx.column_number = 1
    } else {
      ctx.column_number += 1
    }
  })
  ctx.errors.each(fn(error) {
    let text = ctx.input_array[:error.location.index]
    text.each(fn(c) {
      if c == '\n' {
        error.location.line += 1
        error.location.column = 1
      } else {
        error.location.column += 1
      }
    })
  })
  ctx
}

///|
fn merge_context(
  parent_ctx : XMLParserContext,
  child_context : XMLParserContext
) -> XMLParserContext {
  let input_array = parent_ctx.input_array
  input_array.append(child_context.input_array)
  let index = parent_ctx.index + child_context.index
  let errors = parent_ctx.errors
  errors.append(
    child_context.errors.map(fn(error) {
      error.location.index += parent_ctx.index
      error
    }),
  )
  let warnings = parent_ctx.warnings
  warnings.append(child_context.warnings)
  let ctx = {
    input_array,
    index,
    line_number: 0,
    column_number: 0,
    errors,
    warnings,
  }
  ctx
}

// 添加错误处理函数
///|
fn raise_error(
  ctx : XMLParserContext,
  kind : XMLErrorKind,
  index : Int,
  msg : String
) -> XMLParserContext {
  let error = {
    kind,
    message: msg,
    location: { index, line: 0, column: 0, length: 1 },
  }
  ctx.errors.push(error)
  ctx
}

// 解析结果类型
///|
fn bind_error[T](
  parser : Parser[Char, Context[T]],
  error : XMLParseError
) -> Parser[Char, Context[T]] {
  Parser::new(fn(seq) {
    match parser.run(seq) {
      None => abort("Internal Parser Error")
      Some(((None, ctx), remaining_input)) => {
        ctx.errors.push(error)
        Some(((None, ctx), remaining_input))
      }
      Some(((value, ctx), remaining_input)) =>
        Some(((value, ctx), remaining_input))
    }
  })
}

///|
pub fn pwhite_space_with_ctx() -> Parser[Char, Context[String]] {
  // white_space 不需要报错
  @combinator.pchar_such_that(fn(c) {
    c == ' ' || c == '\t' || c == '\r' || c == '\n'
  })
  .repeat()
  .map(fn(ws) {
    let value = ws.iter().fold(init="", fn(s, c) { s + c.to_string() })
    let input_array = ws
    let context = {
      input_array,
      index: ws.length(),
      line_number: 0,
      column_number: 0,
      errors: [],
      warnings: [],
    }
    (Some(value), context)
  })
}

///|
pub fn ptext_with_ctx() -> Parser[Char, Context[String]] {
  //ptext不需要报错
  @combinator.pchar_such_that(fn(c) { c != '<' && c != '&' })
  .repeat()
  .map(fn(chars) {
    let mut content = ""
    chars.each(fn(c) { content = content + c.to_string() })
    let input_array = chars
    let index = chars.length()
    let context = {
      input_array,
      index,
      line_number: 0,
      column_number: 0,
      errors: [],
      warnings: [],
    }
    (Some(content), context)
  })
}

///|
pub fn pname_with_ctx() -> Parser[Char, Context[String]] {
  let parser = @combinator.pchar_such_that(is_name_start_char)
    .and_then(@combinator.pchar_such_that(is_name_char).repeat())
    .map(fn(tuple) {
      let (start, rest) = tuple
      let mut name = start.to_string()
      for c in rest {
        name += c.to_string()
      }
      let input_array = name.to_array()
      let index = name.length()
      let context = {
        input_array,
        index,
        line_number: 0,
        column_number: 0,
        errors: [],
        warnings: [],
      }
      (Some(name), context)
    })
  parser
}

///|
pub fn pattribute_with_ctx() -> Parser[Char, Context[(String, String)]] {
  let parser = pname_with_ctx()
    .and_then(@combinator.pchar('=').and_then(pattValue()).omit_first())
    .map(fn(tuple) {
      let ((name_opt, ctx_1), value) = tuple
      match name_opt {
        Some(key) => {
          let input_array = (key + "=\"" + value + "\"").to_array()
          let context = {
            input_array,
            index: input_array.length(),
            line_number: 0,
            column_number: 0,
            errors: ctx_1.errors,
            warnings: ctx_1.warnings,
          }
          (Some((key, value)), context)
        }
        None => (None, ctx_1)
      }
    })
  parser
}

///|
pub fn pattributes_with_ctx() -> Parser[Char, Context[Map[String, String]]] {
  let parser = pattribute_with_ctx()
    .and_then(pwhite_space_with_ctx())
    .repeat()
    .map(fn(pairs) {
      let mut ctx = {
        input_array: [],
        index: 0,
        line_number: 0,
        column_number: 0,
        errors: [],
        warnings: [],
      }
      let map = pairs.fold(init=Map::new(), fn(map, pair) {
        let ((attr_opt, ctx_1), (ws_opt, ctx_2)) = pair
        match attr_opt {
          Some((key, value)) => {
            if map.contains(key) {
              let _ctx = raise_error(
                ctx_1,
                ValidationError,
                ctx.index + 1,
                "Duplicate attribute: \{key}",
              )
              return map
            }
            map.set(key, value)
          }
          None => ()
        }
        ctx = merge_context(ctx, ctx_1)
        ctx = merge_context(ctx, ctx_2)
        map
      })
      (Some(map), ctx)
    })
  parser
}

///|
pub fn pelement_with_ctx() -> Parser[Char, Context[XMLElement]] {
  let element_ref : Ref[Parser[Char, Context[XMLElement]]] = {
    val: fn { _ => None },
  }
  fn pcontent_with_ctx() -> Parser[Char, Context[Array[XMLChildren]]] {
    let element_parser = @combinator.Parser::from_ref(element_ref).map(fn(
      tuple
    ) {
      let (e_opt, ctx) = tuple
      match e_opt {
        Some(e) => (Some(Element(e)), ctx)
        None => (None, ctx)
      }
    })
    let reference_parser = preference_with_ctx().map(fn(tuple) {
      let (s_opt, ctx) = tuple
      match s_opt {
        Some(s) => (Some(Reference(s)), ctx)
        None => (None, ctx)
      }
    })
    let cdata_parser = pcdata_with_ctx().map(fn(tuple) {
      let (s_opt, ctx) = tuple
      match s_opt {
        Some(s) => (Some(CDATA(s)), ctx)
        None => (None, ctx)
      }
    })
    let pi_parser = ppi_with_ctx().map(fn(tuple) {
      let (pi_opt, ctx) = tuple
      match pi_opt {
        Some(pi) => (Some(XMLChildren::PI(pi)), ctx)
        None => (None, ctx)
      }
    })
    let comment_parser = pcomment_with_ctx().map(fn(tuple) {
      let (s_opt, ctx) = tuple
      match s_opt {
        Some(s) => (Some(XMLChildren::Comment(s)), ctx)
        None => (None, ctx)
      }
    })
    let tail_parser = element_parser
      .or_else(reference_parser)
      .or_else(cdata_parser)
      .or_else(pi_parser)
      .or_else(comment_parser)
      .and_then(ptext_with_ctx().optional())
      .repeat()
    let parser = ptext_with_ctx()
      .optional()
      .map(fn(op) {
        match op {
          Some((text_opt, ctx)) =>
            match text_opt {
              Some(text) =>
                (
                  match trim_text(text) {
                    (head_WS, "", _) => [XMLChildren::WhiteSpace(head_WS)]
                    (head_WS, content, "") =>
                      [WhiteSpace(head_WS), Text(content)]
                    (head_WS, content, tail_WS) =>
                      [WhiteSpace(head_WS), Text(content), WhiteSpace(tail_WS)]
                  },
                  ctx,
                )
              None => ([], ctx)
            }
          None => ([], new_context(""))
        }
      })
      .and_then(tail_parser)
      .map(fn(tuple) {
        let ((arr_1, ctx_1), arr_2) = tuple
        arr_2.each(fn(tuple) {
          let ((child_opt, _ctx_child), op) = tuple
          match child_opt {
            Some(child) => arr_1.push(child)
            None => ()
          }
          match op {
            Some((text_opt, ctx)) => {
              match text_opt {
                Some(text) => arr_1.push(Text(text))
                None => ()
              }
              let _ = merge_context(ctx_1, ctx)

            }
            None => ()
          }
        })
        (Some(arr_1), ctx_1)
      })
    parser
  }

  let empty_parser_with_ctx = @combinator.pchar('<')
    .and_then(pname_with_ctx())
    .omit_first()
    .and_then(pwhite_space_with_ctx())
    .and_then(pattributes_with_ctx())
    .and_then(@combinator.pstring("/>"))
    .omit_second()
    .map(fn(tuple) {
      let (((name_opt, ctx_name), (ws_opt, ctx_ws)), (attrs_opt, ctx_attrs)) = tuple
      match name_opt {
        Some(name) =>
          match attrs_opt {
            Some(attributes) => {
              let element = {
                name,
                empty_element: true,
                attributes,
                children: [],
              }
              let ctx = new_context("<")
                |> merge_context(ctx_name)
                |> merge_context(ctx_ws)
                |> merge_context(ctx_attrs)
                |> merge_context(new_context("/>"))
              (Some(element), ctx)
            }
            None => (None, ctx_attrs)
          }
        None => (None, ctx_name)
      }
    })
  let children_parser_with_ctx = @combinator.pchar('<')
    .and_then(pname_with_ctx())
    .omit_first()
    .and_then(pwhite_space_with_ctx())
    .and_then(pattributes_with_ctx())
    .and_then(@combinator.pchar('>'))
    .omit_second()
    .and_then(pcontent_with_ctx())
    .and_then(
      @combinator.pstring("</")
      .and_then(pname_with_ctx())
      .omit_first()
      .and_then(@combinator.pchar('>'))
      .omit_second()
      .map(fn(tuple) {
        let (name_opt, ctx) = tuple
        let ctx = new_context("</")
          |> merge_context(ctx)
          |> merge_context(new_context(">"))
        (name_opt, ctx)
      }),
    )
    .map(fn(tuple) {
      let (
        (
          (
            ((name_start_opt, ctx_start), (ws_opt, ctx_ws)),
            (attrs_opt, ctx_attrs),
          ),
          (children_opt, ctx_children),
        ),
        (name_end_opt, ctx_end),
      ) = tuple
      match name_start_opt {
        Some(name_start) =>
          match name_end_opt {
            Some(name_end) =>
              match attrs_opt {
                Some(attrs) =>
                  match children_opt {
                    Some(children) => {
                      let ctx = new_context("<")
                        |> merge_context(ctx_start)
                        |> merge_context(ctx_ws)
                        |> merge_context(ctx_attrs)
                        |> merge_context(new_context(">"))
                        |> merge_context(ctx_children)
                        |> merge_context(ctx_end)
                      if name_start != name_end {
                        let _ = raise_error(
                          ctx,
                          MismatchedTags(name_start, name_end),
                          1,
                          "Mismatched start and end tags: \{name_start} and \{name_end}",
                        )

                      }
                      let element = {
                        name: name_start,
                        empty_element: false,
                        attributes: attrs,
                        children,
                      }
                      (Some(element), ctx)
                    }
                    None => (None, ctx_children)
                  }
                None => (None, ctx_attrs)
              }
            None => (None, ctx_end)
          }
        None => (None, ctx_start)
      }
    })
  // 这么组合的性能不够好。 
  let parser = empty_parser_with_ctx.or_else(children_parser_with_ctx)
  element_ref.val = parser
  element_ref.val
}

///|
pub fn pcdata_with_ctx() -> Parser[Char, Context[String]] {
  // TODO : raise error
  let ptail_cdata : Parser[Char, String] = @combinator.Parser::new(fn(seq) {
    let peek3 = peek_char_seq(seq, 3)
    match peek3 {
      Some("]]>") => None
      _ =>
        match seq.uncons() {
          Some((c, rest)) => Some((c.to_string(), rest))
          None => None
        }
    }
  })
  @combinator.pstring("<![CDATA[")
  .and_then(ptail_cdata.repeat())
  .omit_first()
  .and_then(@combinator.pstring("]]>"))
  .omit_second()
  .map(fn { arr => @string.concat(arr, separator="") })
  .map(fn { s => (Some(s), new_context("<![CDATA[\{s}]]>")) })
}

///|
pub fn pcomment_with_ctx() -> Parser[Char, Context[String]] {
  pcomment().map(fn(s) { (Some(s), new_context("<!--\{s}-->")) })
}

///|
pub fn ppi_with_ctx() -> Parser[Char, Context[String]] {
  let ptail_pi : Parser[Char, Char] = @combinator.Parser::new(fn(seq) {
    let peek2 = peek_char_seq(seq, 2)
    match peek2 {
      Some("?>") => None
      _ =>
        match seq.uncons() {
          Some((c, rest)) => Some((c, rest))
          None => None
        }
    }
  })
  @combinator.pstring("<?")
  .and_then(ptail_pi.repeat())
  .omit_first()
  .and_then(@combinator.pstring("?>"))
  .omit_second()
  .map(fn {
    chars => chars.fold(init="", fn(str, char) { str + char.to_string() })
  })
  .map(fn(s) { (Some(s), new_context("<?\{s}?>")) })
}

///|
pub fn pEntityRef_with_ctx() -> Parser[Char, Context[String]] {
  // TODO : Raise ERROR
  // Missing starting '&'
  // Missing ending ';'
  // Empty reference name
  // Invalid reference name characters
  // Unknown entity reference
  @combinator.pchar('&')
  .and_then(pname_with_ctx())
  .and_then(@combinator.pchar(';'))
  .map(fn(tuple) {
    let ((_and, (name_opt, ctx_name)), _semicolon) = tuple
    match name_opt {
      Some(name) => {
        let value = "&" + name + ";"
        let ctx = new_context("&")
        let ctx = merge_context(ctx, ctx_name)
        let ctx = merge_context(ctx, new_context(";"))
        (Some(value), ctx)
      }
      None => (None, ctx_name)
    }
  })
}

///|
pub fn pcharRef_with_ctx() -> Parser[Char, Context[String]] {
  // TODO : raise error
  // Missing '#' after '&'
  // Missing semicolon ';' at end
  // Empty digit sequence
  // Invalid digits (non-decimal/non-hex)
  // Value out of valid XML character range
  let pdecimal = @combinator.pstring("&#")
    .and_then(pdigit)
    .and_then(pdigit.repeat())
    .and_then(@combinator.pchar(';'))
    .map(fn {
      (((_hash, digit), digits), _semicolon) =>
        "#" +
        digit.to_string() +
        digits.fold(init="", fn(str, char) { str + char.to_string() }) +
        ";"
    })
  let phex = @combinator.pstring("&#x")
    .and_then(phexdigit)
    .and_then(phexdigit.repeat())
    .and_then(@combinator.pchar(';'))
    .map(fn {
      (((_hash, digit), digits), _semicolon) =>
        "&#x" +
        digit.to_string() +
        digits.fold(init="", fn(str, char) { str + char.to_string() }) +
        ";"
    })
  pdecimal.or_else(phex).map(fn { s => (Some(s), new_context(s)) })
}

///|
pub fn preference_with_ctx() -> Parser[Char, Context[String]] {
  pEntityRef_with_ctx().or_else(pcharRef_with_ctx())
}

///|
pub fn pprolog_with_ctx() -> Parser[Char, Context[Map[String, String]]] {
  @combinator.pstring("<?xml")
  .and_then(pwhite_space_with_ctx())
  .omit_first()
  .and_then(pattributes_with_ctx())
  .and_then(@combinator.pstring("?>"))
  .omit_second()
  .map(fn(tuple) {
    let ((ws_opt, ctx_ws), (attrs_opt, ctx_attrs)) = tuple
    let ctx = new_context("<?xml")
      |> merge_context(ctx_ws)
      |> merge_context(ctx_attrs)
      |> merge_context(new_context("?>"))
    (attrs_opt, ctx)
  })
}

///|
pub fn pdtd_with_ctx() -> Parser[Char, Context[String]] {
  @combinator.pstring("<!")
  .and_then(@combinator.pchar_such_that(fn(c) { c != '>' }).repeat())
  .omit_first()
  .map(fn(chars) {
    chars.fold(init="", fn(str, char) { str + char.to_string() })
  })
  .and_then(@combinator.pchar('>'))
  .omit_second()
  .map(fn { s => (Some(s), new_context("<!\{s}>")) })
}

///|
pub fn pxml_with_ctx() -> Parser[Char, Context[XMLDocument]] {
  pwhite_space_with_ctx()
  .and_then(pprolog_with_ctx().optional())
  .and_then(pdtd_with_ctx().optional())
  .and_then(pwhite_space_with_ctx())
  .and_then(pelement_with_ctx())
  .map(fn(tuple) {
    let (
      ((((_ws_1_opt, ctx_ws_1), op_prolog), op_dtd), (_ws_2_opt, ctx_ws_2)),
      (element_opt, ctx_element),
    ) = tuple
    match element_opt {
      Some(element) => {
        let ctx = ctx_ws_1
        let map = match op_prolog {
          Some((m_opt, ctx_prolog)) => {
            let _ = ctx |> merge_context(ctx_prolog)
            match m_opt {
              Some(m) => m
              None => Map::new()
            }
          }
          None => Map::new()
        }
        let dtd = match op_dtd {
          Some((dtd_opt, ctx_dtd)) => {
            let _ctx = merge_context(ctx, ctx_dtd)
            match dtd_opt {
              Some(dtd) =>
                Some({ name: dtd, externalID: None, intSubset: None }) // TODO support dtd for ctx version
              None => None
            }
          }
          None => None
        }
        let ctx = ctx |> merge_context(ctx_ws_2) |> merge_context(ctx_element)
        let xml = {
          version: map["version"].or("1.0"),
          encoding: map["encoding"].or("UTF-8"),
          standalone: match map["standalone"] {
            Some("yes") => true
            _ => false
          },
          dtd,
          root: element,
        }
        (Some(xml), ctx)
      }
      None => (None, ctx_element)
    }
  })
}

///|
fn xml_from_string_with_ctx(s : String) -> Context[XMLDocument] {
  let seq = pxml_with_ctx().run(Seq::from_string(s))
  match seq {
    Some(((doc_opt, ctx), _)) =>
      match doc_opt {
        Some(doc) => (Some(doc), ctx |> update_location())
        None => (None, ctx |> update_location())
      }
    None =>
      (
        None,
        raise_error(
          new_context(""),
          InternalParserError,
          1,
          "Internal parser error: please report this bug.",
        ),
      )
  }
}
