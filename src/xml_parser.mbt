///|
let pdigit : Parser[Char, Char] = @combinator.pchar_such_that(is_digit)

///|
test "pdigit" {
  let seq = Seq::from_string("123456")
  let result = pdigit.repeat().run(seq).unwrap()
  println(result)
}

///|
let phexdigit : Parser[Char, Char] = @combinator.pchar_such_that(is_hex_digit)

///|
fn is_digit(c : Char) -> Bool {
  match c {
    '0'..='9' => true
    _ => false
  }
}

///|
fn is_hex_digit(c : Char) -> Bool {
  match c {
    '0'..='9' | 'a'..='f' | 'A'..='F' => true
    _ => false
  }
}

///|
fn is_name_start_char(c : Char) -> Bool {
  match c {
    ':' | '_' | 'a'..='z' | 'A'..='Z' => true
    '\u00C0'..='\u00D6' => true
    '\u00D8'..='\u00F6' => true
    '\u00F8'..='\u02FF' => true
    '\u0370'..='\u037D' => true
    '\u037F'..='\u1FFF' => true
    '\u200C'..='\u200D' => true
    '\u2070'..='\u218F' => true
    '\u2C00'..='\u2FEF' => true
    '\u3001'..='\uD7FF' => true
    '\uF900'..='\uFDCF' => true
    '\uFDF0'..='\uFFFD' => true
    '\u{10000}'..='\u{EFFFF}' => true
    _ => false
  }
}

///|
fn is_name_char(c : Char) -> Bool {
  if is_name_start_char(c) {
    return true
  }
  match c {
    '-'
    | '.'
    | '0'..='9'
    | '\u00B7'
    | '\u0300'..='\u036F'
    | '\u203F'..='\u2040' => true
    _ => false
  }
}

///|
fn is_char(c : Char) -> Bool {
  match c {
    '\u0009'
    | '\u000A'
    | '\u000D'
    | '\u0020'..='\uD7FF'
    | '\uE000'..='\uFFFD'
    | '\u{10000}'..='\u{10FFFF}' => true
    _ => false
  }
}

///|
/// Parses a sequence of whitespace characters (space, tab, carriage return, line
/// feed) into a string.
///
/// Returns a parser that, when applied to an input sequence:
///
/// * Consumes zero or more whitespace characters.
/// * Concatenates all consumed whitespace characters into a single string.
/// * Returns the concatenated string.
///
/// Example:
///
/// ```moonbit
/// test "pwhite_space" {
///   let result = pwhite_space().run(@combinator.Seq::from_string("  \t\n\rtext"))
///   inspect!(result, content="Some((\"  \\t\\n\\r\", 't''e''x''t'))")
/// }
/// ```
pub fn pwhite_space() -> Parser[Char, String] {
  fn is_ws(c : Char) {
    c == '\u0020' || c == '\u0009' || c == '\u000D' || c == '\u000A'
  }

  @combinator.pchar_such_that(is_ws)
  .and_then(@combinator.pchar_such_that(is_ws).repeat())
  .map(fn(tuple) {
    let (ws, arr) = tuple
    arr.iter().fold(init=ws.to_string(), fn(s, c) { s + c.to_string() })
  })
}

///|
/// Parses XML text content excluding special characters ('<' and '&').
///
/// Parameters:
///
/// * `input` : A sequence of characters to be parsed. Should not contain any
/// instances of '<' or '&'.
///
/// Returns a `Parser[Char, String]` that, when applied to an input sequence:
///
/// * Succeeds and produces a `String` representing the concatenated characters
/// that are not '<' or '&'.
/// * Fails if any character in the sequence is '<' or '&'.
///
/// Example:
///
/// ```moonbit
/// test "ptext/simple_text" {
///   let result = ptext().run(@combinator.Seq::from_string("Hello World"))
///   inspect!(result, content="Some((\"Hello World\", ))")
/// }
/// 
/// test "ptext/with_special_characters" {
///   let result = ptext().run(@combinator.Seq::from_string("Text with & and <"))
///   inspect!(result, content="Some((\"Text with \", '&'' ''a''n''d'' ''<'))") // stops parsing at '&'
/// }
/// 
/// test "panic ptext/empty_input" {
///   let result = ptext().run(@combinator.Seq::from_string(""))
///   inspect!(result, content="None")
/// }
/// ```
pub fn ptext() -> Parser[Char, String] {
  @combinator.pchar_such_that(fn(c) { c != '<' && c != '&' })
  .repeat()
  .map(fn(chars) {
    let mut content = ""
    chars.each(fn(c) { content = content + c.to_string() })
    content
  })
}

// 解析 XML 标签名

///|
/// Parses an XML name according to the XML 1.0 specification. An XML name must
/// start with a name start character (letter, underscore, or colon) followed by
/// zero or more name characters (letters, digits, dots, hyphens, underscores, or
/// colons).
///
/// Returns a parser that, when successful, produces a string containing the
/// parsed XML name.
///
/// Example:
///
/// ```moonbit
/// test "pname" {
///   // Valid XML names
///   let result1 = pname().run(@combinator.Seq::from_string("element1"))
///   inspect!(result1, content="Some((\"element1\", ))")
/// 
///   // Invalid XML names (starting with digit)
///   let result2 = pname().run(@combinator.Seq::from_string("1element"))
///   inspect!(result2, content="None")
/// }
/// ```
pub fn pname() -> Parser[Char, String] {
  @combinator.pchar_such_that(is_name_start_char)
  .and_then(@combinator.pchar_such_that(is_name_char).repeat())
  .map(fn(tuple) {
    let (start, rest) = tuple
    let mut name = start.to_string()
    for c in rest {
      name += c.to_string()
    }
    name
  })
}

///|
test "pname/valid_name" {
  // Boundary case: Valid XML name with minimum length
  let result = pname().run(Seq::from_string("a"))
  println("result is " + result.to_string())
  inspect(result, content="Some((\"a\", ))")

  // Boundary case: Valid XML name with typical characters
  let result = pname().run(Seq::from_string("root"))
  inspect(result, content="Some((\"root\", ))")

  // Boundary case: Valid XML name with mixed characters
  let result = pname().run(Seq::from_string("xml:Root123"))
  inspect(result, content="Some((\"xml:Root123\", ))")

  // Boundary case: Valid XML name with extended characters
  let result = pname().run(Seq::from_string("🐇"))
  inspect(result, content="Some((\"🐇\", ))")
}

///|
test "panic pname/invalid_name" {
  // Boundary case: Invalid XML name with invalid start character
  let result = pname().run(Seq::from_string("1invalid"))
  inspect(result, content="None")

  // Boundary case: Invalid XML name with invalid character in the name
  let result = pname().run(Seq::from_string("root%"))
  inspect(result, content="None")
  let result = pname().run(Seq::from_string("\u{FFFFF}"))
  inspect(result, content="None")
}

///|
fn pattValue() -> Parser[Char, String] {
  fn pattValue_quote(quote : Char) -> Parser[Char, String] {
    @combinator.pchar(quote)
    .and_then(
      @combinator.pchar_such_that(fn(c) { c != quote && c != '<' && c != '&' })
      .map(fn(c) { c.to_string() })
      .or_else(preference())
      .repeat()
      .and_then(@combinator.pchar(quote))
      .map(fn(tuple) {
        let chars = tuple.0
        let mut value = ""
        chars.each(fn(s) { value = value + s })
        value
      }),
    )
    .omit_first()
  }

  pattValue_quote('"').or_else(pattValue_quote('\''))
}

// 解析 XML 属性

///|
/// Parses an XML attribute, which consists of a name followed by an equals sign
/// and a quoted string value.
///
/// Parameters:
///
/// * `input` : A sequence of characters representing the XML attribute to be
/// parsed. The sequence should start with a valid XML name followed by "=" and a
/// double-quoted string value.
///
/// Returns a `Parser[Char, (String, String)]` that, when applied to an input
/// sequence:
///
/// * Succeeds with a tuple containing the attribute name and value if parsing is
/// successful
/// * Fails if the input does not match the expected XML attribute format
///
/// Example:
///
/// ```moonbit
/// test "pattribute/basic" {
///   let result = pattribute().run(@combinator.Seq::from_string("name=\"value\""))
///   inspect!(result, content="Some(((\"name\", \"value\"), ))")
/// }
/// ```
pub fn pattribute() -> Parser[Char, (String, String)] {
  pname()
  .and_then(pwhite_space().optional())
  .omit_second()
  .and_then(
    @combinator.pchar('=')
    .and_then(pwhite_space().optional())
    .omit_second()
    .and_then(pattValue())
    .omit_first(),
  )
  .map(fn(tuple) { (tuple.0, tuple.1) })
}

///|
test "pattribute/valid" {
  // Basic valid attribute
  let result = pattribute().run(Seq::from_string("name=\"1234567890\""))
  inspect(result, content="Some(((\"name\", \"1234567890\"), ))")
  // Single quotes
  let result2 = pattribute().run(Seq::from_string("name='value'"))
  inspect(result2, content="Some(((\"name\", \"value\"), ))")
}

///|
test "pattribute/invalid_format" {
  // Missing quotes around value
  let result = pattribute().run(Seq::from_string("name=value"))
  inspect(result, content="None")

  // Missing equals sign
  let result2 = pattribute().run(Seq::from_string("name\"value\""))
  inspect(result2, content="None")

  // quotes not matching
  let result3 = pattribute().run(Seq::from_string("name=\"value'"))
  inspect(result3, content="None")
  let result4 = pattribute().run(Seq::from_string("name='value\""))
  inspect(result4, content="None")
}

///|
/// Parses a sequence of XML attributes, each followed by optional whitespace.
/// Combines all parsed attributes into a map where keys are attribute names and
/// values are corresponding attribute values.
///
/// Returns a parser that produces a map from attribute names to their values.
/// The parser succeeds even if no attributes are present, returning an empty
/// map.
///
/// Example:
///
/// ```moonbit
/// test "pattributes/basic" {
///   let result = pattributes().run(
///     @combinator.Seq::from_string(" name=\"value\" type=\"text\""),
///   )
///   let attrs = result.unwrap().0
///   inspect!(attrs.get("name"), content="Some(\"value\")")
///   inspect!(attrs.get("type"), content="Some(\"text\")")
/// }
/// ```
pub fn pattributes() -> Parser[Char, Map[String, String]] {
  pwhite_space()
  .and_then(pattribute())
  .omit_first()
  .repeat()
  .map(fn(attrs) {
    attrs.fold(init=Map::new(), fn(map, tuple) {
      map.set(tuple.0, tuple.1)
      map
    })
  })
}

///|
test "pattributes/empty" {
  // Test case for empty attributes
  let result = pattributes().run(Seq::from_string(""))
  inspect(result, content="Some(({}, ))")
}

///|
test "pattributes/single" {
  // Test case for single attribute
  let result = pattributes().run(Seq::from_string(" name=\"value\""))
  let map = result.unwrap().0
  inspect(map.size(), content="1")
  inspect(map.get("name"), content="Some(\"value\")")
}

///|
test "pattributes/single" {
  // Test case for single attribute
  let result = pattributes().run(
    Seq::from_string(" name=\"value\" lang=\"en\""),
  )
  let map = result.unwrap().0
  inspect(map.size(), content="2")
  inspect(map.get("name"), content="Some(\"value\")")
}

///|
test "panic pattributes/invalid_format" {
  // Test case for invalid attribute format
  let result = pattributes().run(Seq::from_string("name=value"))
  inspect(result, content="None")
}

///|
fn trim_text(text : String) -> (String, String, String) {
  // text should not be empty
  let seq = Seq::from_string(text)
  let (head_WS, rest) = match pwhite_space().run(seq) {
    Some((ws, rest)) => (ws, rest)
    None => ("", seq)
  }
  if rest.is_empty() {
    return (head_WS, "", "")
  }
  let seq = Seq::from_string(text.rev())
  let tail_WS = match pwhite_space().run(seq) {
    Some((ws, _)) => ws.rev()
    None => ""
  }
  let content = text.substring(
    start=head_WS.length(),
    end=text.length() - tail_WS.length(),
  )
  (head_WS, content, tail_WS)
}

// 解析 XML 元素

///|
/// Parses an XML element, which can be either an empty element (e.g., `<br/>`)
/// or an element with content (e.g., `<div>...</div>`). The parser handles
/// nested elements, text content, CDATA sections, processing instructions,
/// comments, and entity references.
///
/// Parameters:
///
/// * `input` : A sequence of characters representing an XML element. The
/// sequence should start with an opening tag (e.g., `<tag>`) and end with either
/// a self-closing tag (e.g., `/>`) or a matching closing tag (e.g., `</tag>`).
///
/// Returns a parser that produces an `XMLElement` structure containing:
///
/// * The element's name
/// * A map of attribute names to their values
/// * A queue of child nodes (`XMLChildren`)
///
/// Example:
///
/// ```moonbit
/// test "pelement/basic" {
///   // Parse a simple XML element with attributes and text content
///   let input = "<user id=\"1\" name=\"John\">Hello, World!</user>"
///   let result = pelement().run(@combinator.Seq::from_string(input))
///   let element = result.unwrap().0
///   inspect!(element.name, content="user")
///   inspect!(element.attributes.get("id"), content="Some(\"1\")")
///   inspect!(element.attributes.get("name"), content="Some(\"John\")")
/// }
/// ```
pub fn pelement() -> Parser[Char, XMLElement] {
  let element_ref : Ref[Parser[Char, XMLElement]] = { val: fn { _ => None } }
  fn pcontent() -> Parser[Char, Array[XMLChildren]] {
    let element_parser = @combinator.Parser::from_ref(element_ref).map(fn(e) {
      Element(e)
    })
    let reference_parser = preference().map(fn(s) { Reference(s) })
    let cdata_parser = pcdata().map(fn(s) { CDATA(s) })
    let pi_parser = ppi().map(fn(pi) { XMLChildren::PI(pi) })
    let comment_parser = pcomment().map(fn(s) { XMLChildren::Comment(s) })
    let tail_parser = element_parser
      .or_else(reference_parser)
      .or_else(cdata_parser)
      .or_else(pi_parser)
      .or_else(comment_parser)
      .and_then(ptext().optional())
      .repeat()
    let parser = ptext()
      .optional()
      .map(fn(op) {
        match op {
          Some(text) =>
            match trim_text(text) {
              (head_WS, "", _) => [XMLChildren::WhiteSpace(head_WS)]
              (head_WS, content, "") => [WhiteSpace(head_WS), Text(content)]
              (head_WS, content, tail_WS) =>
                [WhiteSpace(head_WS), Text(content), WhiteSpace(tail_WS)]
            }
          None => []
        }
      })
      .and_then(tail_parser)
      .map(fn(tuple) {
        let (queue, arr) = tuple
        arr.each(fn(pair) {
          let (child, op) = pair
          queue.push(child)
          match op {
            Some(text) => queue.push(Text(text))
            None => ()
          }
        })
        queue
      })
    parser
  }

  let empty_parser = @combinator.pchar('<')
    .and_then(pname())
    .omit_first()
    .and_then(pattributes())
    .and_then(pwhite_space().optional())
    .omit_second()
    .and_then(@combinator.pstring("/>"))
    .omit_second()
    .map(fn {
      (name, attributes) =>
        { name, empty_element: true, attributes, children: [] }
    })
  let children_parser = @combinator.pchar('<')
    .and_then(pname())
    .omit_first()
    .and_then(pattributes())
    .and_then(pwhite_space().optional())
    .omit_second()
    .and_then(@combinator.pchar('>'))
    .omit_second()
    .map(fn(x) { x })
    .and_then(pcontent())
    .map(fn(x) { x })
    .and_then(
      @combinator.pstring("</")
      .and_then(pname())
      .omit_first()
      .and_then(pwhite_space().optional())
      .omit_second()
      .and_then(@combinator.pchar('>'))
      .omit_second(),
    )
    .map(fn(tuple) {
      let (((name_start, attrs), children), name_end) = tuple
      if name_start != name_end {
        // TODO raiseError
        // raise XMLParseError("Mismatched start and end tags")
        println("Mismatched start and end tags")
      }
      { name: name_start, empty_element: false, attributes: attrs, children }
    })
  // 这么组合的性能不够好。 
  let parser = empty_parser.or_else(children_parser)
  element_ref.val = parser
  return element_ref.val
}

///|
test "pelement/empty" {
  // Test empty element with no attributes
  let result = pelement().run(Seq::from_string("<br/>"))
  inspect(result, content="Some((XMLElement: <br/>, ))")
  // Test empty element with multiple attributes and special characters
  let result2 = pelement().run(
    Seq::from_string(
      "<meta name=\"description\" content=\"Test &and; Demo\" charset=\"UTF-8\"/>",
    ),
  )
  let element = result2.unwrap().0
  inspect(element.name, content="meta")
  inspect(element.attributes.get("name"), content="Some(\"description\")")
  inspect(
    element.attributes.get("content"),
    content="Some(\"Test &and; Demo\")",
  )
  inspect(element.attributes.get("charset"), content="Some(\"UTF-8\")")
  inspect(element.children.length(), content="0")
}

///|
test "pelement/complex" {
  let xml =
    #|<root id="main">
    #|  Some text
    #|  <child class="nested">Child text</child>
    #|  <!-- This is a comment -->
    #|  <![CDATA[This is <CDATA> content]]>
    #|  <?php echo "processing instruction" ?>
    #|  <empty-child/>
    #|  &lt;reference&gt;
    #|  <deep>
    #|    <nested>
    #|      <structure>Deep text</structure>
    #|    </nested>
    #|  </deep>
    #|</root>
    #|
  let result = pelement().run(@combinator.Seq::from_string(xml))
  let element = result.unwrap().0
  // Check root element
  inspect(element.name, content="root")
  inspect(element.attributes.get("id"), content="Some(\"main\")")
}

///|
fn peek_char_seq(seq : Seq[Char], n : Int) -> String? {
  // help me return Some(first n char to string) in seq, or return None
  Seq::peek_char(seq, n)
}

///|
/// Parses a CDATA section in XML, which allows text containing characters that
/// would otherwise need to be escaped. A CDATA section starts with "<![CDATA["
/// and ends with "]]>". The content between these markers is treated as plain
/// text, not XML markup.
///
/// Parameters:
///
/// * `seq` : The input sequence of characters to be parsed. Expected to start
/// with a CDATA section.
///
/// Returns a parser that produces the content of the CDATA section as a string,
/// excluding the CDATA markers.
///
/// Example:
///
/// ```moonbit
/// test "pcdata/basic" {
///   let input = "<![CDATA[Some <raw> XML & content]]>"
///   let result = pcdata().run(@combinator.Seq::from_string(input))
///   inspect!(result, content="Some((\"Some <raw> XML & content\", ))")
/// }
/// 
/// test "pcdata/empty" {
///   let input = "<![CDATA[]]>"
///   let result = pcdata().run(@combinator.Seq::from_string(input))
///   inspect!(result, content="Some((\"\", ))")
/// }
/// ```
pub fn pcdata() -> Parser[Char, String] {
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
}

///|
/// Parses an XML comment. A comment in XML starts with "<!--" and ends with
/// "-->". The parser captures all characters between these delimiters, excluding
/// the delimiters themselves.
///
/// Parameters:
///
/// * `seq` : A sequence of characters representing the XML content to be parsed.
/// The sequence should start with an XML comment.
///
/// Returns a parser that produces a string containing the comment content when
/// successful, or fails if the input is not a valid XML comment.
///
/// Example:
///
/// ```moonbit
/// test "pcomment/basic" {
///   let comment = "<!-- This is a comment -->"
///   let result = pcomment().run(@combinator.Seq::from_string(comment))
///   inspect!(result, content="Some((\" This is a comment \", ))")
/// }
/// ```
pub fn pcomment() -> Parser[Char, String] {
  let pvalidNonDashChar = @combinator.pchar_such_that(fn(c) {
    is_char(c) && c != '-'
  }).map(fn { c => c.to_string() })
  let pdashFollowedByValidChar = @combinator.pchar('-')
    .and_then(pvalidNonDashChar)
    .map(fn { (_, c) => "-" + c })
  let pcommentContent = pvalidNonDashChar
    .or_else(pdashFollowedByValidChar)
    .repeat()
    .map(fn { arr => @string.concat(arr, separator="") })
  @combinator.pstring("<!--")
  .and_then(pcommentContent)
  .omit_first()
  .and_then(@combinator.pstring("-->"))
  .omit_second()
}

///|
fn not_xml(c : Char) -> Bool {
  c != 'x' && c != 'X' && c != 'm' && c != 'M' && c != 'l' && c != 'L'
}

///|
pub fn ppiTarget() -> Parser[Char, String] {
  @combinator.pchar_such_that(is_name_start_char)
  .and_then(@combinator.pchar_such_that(is_name_char).repeat())
  .map(fn(tuple) {
    let (start, rest) = tuple
    let mut name = start.to_string()
    for c in rest {
      name += c.to_string()
    }
    name
  })
}

///|
/// Parses an XML processing instruction (PI) from a sequence of characters. A
/// processing instruction begins with "<?", followed by arbitrary content not
/// containing "?>", and ends with "?>".
///
/// Returns a parser that, when applied to an input sequence:
///
/// * Succeeds with the content of the processing instruction (excluding the "<?"
/// and "?>" delimiters) if a valid PI is found
/// * Fails if the input does not start with a valid processing instruction
///
/// Example:
///
/// ```moonbit
/// test "ppi/basic" {
///   let result = ppi().run(@combinator.Seq::from_string("<?php echo 'Hello' ?>"))
///   inspect!(result, content="Some((\"php echo 'Hello' \", ))")
/// }
/// 
/// test "ppi/empty" {
///   let result = ppi().run(@combinator.Seq::from_string("<??>"))
///   inspect!(result, content="Some((\"\", ))")
/// }
/// 
/// test "ppi/invalid" {
///   let result = ppi().run(@combinator.Seq::from_string("<?incomplete"))
///   inspect!(result, content="None")
/// }
/// ```
/// TODO 
/// 	PI	   ::=   	'<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'
/// 	PITarget	   ::=   	Name - (('X' | 'x') ('M' | 'm') ('L' | 'l'))
pub fn ppi() -> Parser[Char, String] {
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
}

///|
test "pcomment/empty" {
  // Empty comment
  let result = pcomment().run(Seq::from_string("<!---->"))
  inspect(result, content="Some((\"\", ))")
}

///|
test "pcomment/with_content" {
  // Comment with various content including special characters
  let result = pcomment().run(
    Seq::from_string("<!-- This is a comment with <tags> and &symbols& -->"),
  )
  inspect(
    result,
    content="Some((\" This is a comment with <tags> and &symbols& \", ))",
  )
}

///|
test "pcomment/invalid" {
  // Incomplete comment
  let result = pcomment().run(Seq::from_string("<!--"))
  inspect(result, content="None")

  // Missing opening sequence
  let result2 = pcomment().run(Seq::from_string("Comment -->"))
  inspect(result2, content="None")
}

///|
/// Parses an XML entity reference of the form `&name;`, where `name` is a valid
/// XML name.
///
/// Returns a `Parser` that accepts a sequence of characters and produces a
/// `String` containing the complete entity reference. For example, parsing
/// `&lt;` will return `"&lt;"`.
///
/// Example:
///
/// ```moonbit
/// test "pEntityRef" {
///   let result = pEntityRef().run(@combinator.Seq::from_string("&lt;"))
///   inspect!(result, content="Some((\"&lt;\", ))")
/// }
/// ```
pub fn pEntityRef() -> Parser[Char, String] {
  @combinator.pchar('&')
  .and_then(pname())
  .and_then(@combinator.pchar(';'))
  .map(fn { ((_and, name), _semicolon) => "&" + name + ";" })
}

///|
/// Parses a character reference in XML, which can be either a decimal reference
/// (\&#d;) or a hexadecimal reference (\&#xh;) where 'd' is a sequence of
/// decimal digits and 'h' is a sequence of hexadecimal digits.
///
/// Returns a `Parser[Char, String]` that, when applied to an input sequence:
///
/// * For decimal references, matches patterns like "{"
/// * For hexadecimal references, matches patterns like "¥"
/// * Returns the matched reference as a string, including the delimiters
///
/// Example:
///
/// ```moonbit
/// test "pcharRef" {
///   let decimal = pcharRef().run(@combinator.Seq::from_string("&#123;"))
///   let hex = pcharRef().run(@combinator.Seq::from_string("&#xA5;"))
///   inspect!(decimal, content="Some((\"#123;\", ))")
///   inspect!(hex, content="Some((\"#A5;\", ))")
/// }
/// ```
pub fn pcharRef() -> Parser[Char, String] {
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
        "#" +
        digit.to_string() +
        digits.fold(init="", fn(str, char) { str + char.to_string() }) +
        ";"
    })
  pdecimal.or_else(phex)
}

///|
/// Parses an XML reference, which can be either an entity reference (like
/// `&amp;`) or a character reference (like `&#x20;` or `&#32;`).
///
/// Returns a parser that succeeds with the reference string if the input matches
/// either an entity reference or a character reference pattern, and fails
/// otherwise.
///
/// Example:
///
/// ```moonbit
/// test "preference/basic" {
///   // Entity reference
///   let entity = preference().run(@combinator.Seq::from_string("&amp;"))
///   inspect!(entity, content="Some((\"&amp;\", ))")
/// 
///   // Character reference (decimal)
///   let decimal = preference().run(@combinator.Seq::from_string("&#32;"))
///   inspect!(decimal, content="Some((\"#32;\", ))")
/// 
///   // Character reference (hexadecimal)
///   let hex = preference().run(@combinator.Seq::from_string("&#x20;"))
///   inspect!(hex, content="Some((\"#20;\", ))")
/// }
/// ```
pub fn preference() -> Parser[Char, String] {
  pEntityRef().or_else(pcharRef())
}

///|
/// Parses an XML prolog declaration, which appears at the beginning of an XML
/// document. The prolog typically contains information about XML version,
/// encoding, and standalone status.
///
/// Returns a parser that, when applied to an input sequence:
///
/// * Succeeds with a map containing prolog attributes if the input starts with a
/// valid XML prolog
/// * Fails if the input does not match the XML prolog syntax: `<?xml
/// attr1="value1" attr2="value2"?>`
///
/// Example:Have
/// test "pprolog/basic" {
///   let input = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
///   let result = pprolog().run(Seq::from_string(input))
///   let attrs = result.unwrap().0
///   inspect!(attrs.get("version"), content="Some(\"1.0\")")
///   inspect!(attrs.get("encoding"), content="Some(\"UTF-8\")")
/// }
/// ```
pub fn pprolog() -> Parser[Char, Map[String, String]] {
  @combinator.pstring("<?xml")
  .and_then(pattributes())
  .and_then(pwhite_space().optional())
  .omit_second()
  .omit_first()
  .and_then(@combinator.pstring("?>"))
  .omit_second()
}

///|
test "pprolog/valid_prolog_with_spaces" {
  let result = pprolog().run(
    Seq::from_string(
      "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>",
    ),
  )
  inspect(
    result,
    content="Some(({\"version\": \"1.0\", \"encoding\": \"UTF-8\", \"standalone\": \"yes\"}, ))",
  )
}

///|
test "pprolog/minimal_valid_prolog" {
  let result = pprolog().run(Seq::from_string("<?xml ?>"))
  inspect(result, content="Some(({}, ))")
}

///|
/// Parses a Document Type Definition (DTD) declaration in an XML document.
/// Starts with "\<!" and ends with ">", capturing all characters in between
/// except for the closing angle bracket.
///
/// Returns a parser that, when applied to an input sequence:
///
/// * Succeeds with the contents of the DTD declaration as a string, excluding
/// the opening "\<!" and closing ">" delimiters
/// * Fails if the input doesn't match the expected DTD format
///
/// Example:
///
/// ```moonbit
/// test "pdtd/basic" {
///   let result = pdtd().run(@combinator.Seq::from_string("<!DOCTYPE html>")).unwrap().0
///   inspect!(result, content="<!DOCTYPE html>")
/// }
/// ```
pub fn pdtd() -> Parser[Char, DocTypeDecl] {
  @combinator.pstring("<!DOCTYPE")
  .and_then(pwhite_space())
  .and_then(pname())
  .omit_first()
  .and_then(pwhite_space().and_then(pexternalID()).omit_first().optional())
  .and_then(pwhite_space().optional())
  .omit_second()
  .and_then(
    @combinator.pstring("[")
    .and_then(pinternalSubset())
    .omit_first()
    .and_then(@combinator.pstring("]"))
    .omit_second()
    .and_then(pwhite_space().optional())
    .omit_second()
    .optional(),
  )
  .and_then(@combinator.pchar('>'))
  .omit_second()
  .map(fn(tuple) {
    let ((name, externalID), intSubset) = tuple
    { name, externalID, intSubset }
  })
}

///|
/// Parses a complete XML document string into an `XMLDocument` structure.
/// Handles XML prolog, DOCTYPE declaration (DTD), and the root element with its
/// contents. Supports whitespace between major components.
///
/// Parameters:
///
/// * `seq` : A sequence of characters representing the XML document to be
/// parsed. Should contain optional XML prolog, optional DOCTYPE declaration, and
/// exactly one root element.
///
/// Returns a `Parser[Char, XMLDocument]` that, when applied to an input
/// sequence:
///
/// * Succeeds with an `XMLDocument` containing version (defaults to "1.0"),
/// encoding (defaults to "UTF-8"), standalone flag, and the parsed root element.
/// * Fails if the input is not a well-formed XML document.
///
/// Example:
///
/// ```moonbit
/// test "pxml/basic" {
///   let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><root><child>Text</child></root>"
///   let result = pxml().run(@combinator.Seq::from_string(xml))
///   let doc = result.unwrap().0
///   inspect!(doc.version, content="1.0")
///   inspect!(doc.root.name, content="root")
/// }
/// ```
pub fn pxml() -> Parser[Char, XMLDocument] {
  pwhite_space()
  .optional()
  .and_then(pprolog().optional())
  .omit_first()
  .and_then(pmisc().repeat())
  .omit_second()
  .and_then(pdtd().and_then(pmisc().repeat()).omit_second().optional())
  .and_then(pwhite_space().optional())
  .omit_second()
  .and_then(pelement())
  .map(fn(tuple) {
    let ((map, dtd), element) = tuple
    let map = match map {
      Some(m) => m
      None => Map::new()
    }
    {
      version: map.get("version").or("1.0"),
      encoding: map.get("encoding").or("UTF-8"),
      standalone: match map.get("standalone") {
        Some("yes") => true
        _ => false
      },
      dtd,
      root: element,
    }
  })
}

///|
test "pxml/complex_nested" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<root id="main">
    #|  <header class="top">
    #|    <title>My Document</title>
    #|    <!-- Navigation section -->
    #|    <nav>
    #|      <item href="/home">Home</item>
    #|      <item href="/about">About</item>
    #|    </nav>
    #|  </header>
    #|  <content>
    #|    <![CDATA[Some <raw> content & data]]>
    #|    <section>
    #|      <p>Normal text</p>
    #|      <p>Special chars: &lt; &gt; &amp;</p>
    #|    </section>
    #|  </content>
    #|</root>
    #|
  let result = pxml().run(Seq::from_string(xml))
  let doc = result.unwrap().0

  // Check basic document properties
  inspect(doc.version, content="1.0")
  inspect(doc.encoding, content="UTF-8")
  inspect(doc.standalone, content="false")

  // Check root element
  inspect(doc.root.name, content="root")
  inspect(doc.root.attributes.get("id"), content="Some(\"main\")")
}

///|
test "pxml/mixed_content" {
  let xml =
    #|<?xml version="1.0"?>
    #|<root>
    #|  Text before
    #|  <child empty="true"/>
    #|  Text between
    #|  <?php echo "processing instruction" ?>
    #|  <![CDATA[Preserving <tags> in CDATA]]>
    #|  <!-- A comment here -->
    #|  <child>
    #|    Nested text
    #|    <grandchild />
    #|    More nested text
    #|  </child>
    #|  Text after
    #|</root>
    #|
  let result = pxml().run(Seq::from_string(xml))
  let doc = result.unwrap().0
  inspect(doc.version, content="1.0")
  inspect(doc.root.name, content="root")

  // Check that root has children
  inspect(doc.root.children.is_empty(), content="false")
}

///|
test "pxml/basic_xml_no_attributes" {
  let xml = "<root></root>"
  let result = pxml().run(Seq::from_string(xml))
  let document = result.unwrap().0
  inspect(document.version, content="1.0")
  inspect(document.encoding, content="UTF-8")
  inspect(document.standalone, content="false")
  inspect(document.root.name, content="root")
  inspect(document.root.attributes.size(), content="0")
}

///|
test "pxml/basic_xml_with_attributes" {
  let xml = "<?xml version=\"1.1\" encoding=\"ISO-8859-1\" standalone=\"yes\"?><root attr1=\"value1\" attr2=\"value2\"></root>"
  let result = pxml().run(Seq::from_string(xml))
  let document = result.unwrap().0
  inspect(document.version, content="1.1")
  inspect(document.encoding, content="ISO-8859-1")
  inspect(document.standalone, content="true")
  inspect(document.root.name, content="root")
  inspect(document.root.attributes.size(), content="2")
  inspect(document.root.attributes.get("attr1"), content="Some(\"value1\")")
  inspect(document.root.attributes.get("attr2"), content="Some(\"value2\")")
}

///|
test "pxml/mismatched_start_end_tags" {
  let xml = "<root><child></root>"
  ignore(pxml().run(Seq::from_string(xml)))
}

///|
/// Parses an XML string and converts it into an XMLDocument structure. The input
/// string should contain a well-formed XML document with a single root element.
///
/// Parameters:
///
/// * `xml_string` : A string containing the XML document to be parsed.
///
/// Returns an `Option` type containing the parsed `XMLDocument` if successful,
/// or `None` if the parsing fails due to invalid XML syntax.
///
/// Example:
///
/// ```moonbit
/// test "xml_from_string/basic" {
///   let xml = "<?xml version=\"1.0\"?><root><child>Content</child></root>"
///   let doc = xml_from_string(xml).unwrap()
///   inspect!(doc.root.name, content="root")
/// }
/// ```
pub fn xml_from_string(s : String) -> XMLDocument? {
  let result = pxml().run(Seq::from_string(s))
  match result {
    Some((doc, _)) => Some(doc)
    None => None
  }
}

///|
fn iter_to_seq(iter : Iter[Char]) -> Seq[Char] {
  Seq::from_array(iter.to_array()[:])
}

///| This function is slower than xml_from_string. Have O(n^2) complexity.
pub fn xml_from_iter(iter : Iter[Char]) -> XMLDocument? {
  let seq = iter_to_seq(iter)
  let result = pxml().run(seq)
  match result {
    Some((doc, _)) => Some(doc)
    None => None
  }
}
