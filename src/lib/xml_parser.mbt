///|
typealias Parser[Token, Value] = @combinator.Parser[Token, Value]

///|
typealias Seq[T] = @combinator.Seq[T]

///|
type! XMLParseError String

///|
let digit : Parser[Char, Char] = @combinator.one_of([
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
])

///|
let hexdigit : Parser[Char, Char] = @combinator.one_of([
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 'A', 'B', 'C', 'D', 'E',
  'F', 'a', 'b', 'c', 'd', 'e', 'f',
])

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
    _ => false
  }
}

///|
/// Checks if a character is valid for use in an XML name (element names,
/// attribute names, etc.) according to the XML 1.0 specification. This includes
/// name start characters and additional characters allowed in non-initial
/// positions.
///
/// Parameters:
///
/// * `char` : The character to be checked. Can be any Unicode character.
///
/// Returns `true` if the character is valid in an XML name, `false` otherwise.
///
/// Example:
///
/// ```moonbit
/// test "is_name_char/valid_chars" {
///   inspect!(is_name_char('a'), content="true") // letters are valid
///   inspect!(is_name_char('1'), content="true") // digits are valid
///   inspect!(is_name_char('.'), content="true") // dots are valid
///   inspect!(is_name_char(' '), content="false") // spaces are invalid
/// }
/// ```
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
pub fn pwhite_space() -> Parser[Char, String] {
  @combinator.pchar_such_that(fn(c) {
    c == ' ' || c == '\t' || c == '\r' || c == '\n'
  })
  .repeat()
  .map(fn(ws) { ws.iter().fold(init="", fn(s, c) { s + c.to_string() }) })
}

///|
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

test "pname/valid_name" {
  // Boundary case: Valid XML name with minimum length
  let result = pname().parse(Seq::from_string("a"))
  println("result is " + result.to_string())
  inspect!(result, content="Some((\"a\", ))")

  // Boundary case: Valid XML name with typical characters
  let result = pname().parse(Seq::from_string("root"))
  inspect!(result, content="Some((\"root\", ))")

  // Boundary case: Valid XML name with mixed characters
  let result = pname().parse(Seq::from_string("xml:Root123"))
  inspect!(result, content="Some((\"xml:Root123\", ))")
}

test "panic pname/invalid_name" {
  // Boundary case: Invalid XML name with invalid start character
  let result = pname().parse(Seq::from_string("1invalid"))
  inspect!(result, content="None")

  // Boundary case: Invalid XML name with invalid character in the name
  let result = pname().parse(Seq::from_string("root%"))
  inspect!(result, content="None")
}

// 解析 XML 属性
///|
pub fn pattribute() -> Parser[Char, (String, String)] {
  pname()
  .and_then(
    @combinator.pchar('=')
    .and_then(
      @combinator.pchar('"')
      .and_then(
        @combinator.pchar_such_that(fn(c) { c != '"' })
        .repeat()
        .and_then(@combinator.pchar('"'))
        .map(fn(tuple) {
          let chars = tuple.0
          let mut value = ""
          chars.each(fn(c) { value = value + c.to_string() })
          value
        }),
      )
      .omit_first(),
    )
    .omit_first(),
  )
  .map(fn(tuple) { (tuple.0, tuple.1) })
}

test "pattribute/valid" {
  // Basic valid attribute
  let result = pattribute().parse(Seq::from_string("name=\"1234567890\""))
  inspect!(result, content="Some(((\"name\", \"1234567890\"), ))")
}

test "pattribute/invalid_format" {
  // Missing quotes around value
  let result = pattribute().parse(Seq::from_string("name=value"))
  inspect!(result, content="None")

  // Missing equals sign
  let result2 = pattribute().parse(Seq::from_string("name\"value\""))
  inspect!(result2, content="None")
}

///|解析 XML 属性列表
pub fn pattributes() -> Parser[Char, Map[String, String]] {
  pattribute()
  .and_then(pwhite_space())
  .omit_second()
  .repeat()
  .map(fn(attrs) {
    attrs.fold(init=Map::new(), fn(map, tuple) {
      map.set(tuple.0, tuple.1)
      map
    })
  })
}

test "pattributes/empty" {
  // Test case for empty attributes
  let result = pattributes().parse(Seq::from_string(""))
  inspect!(result, content="Some(({}, ))")
}

test "pattributes/single" {
  // Test case for single attribute
  let result = pattributes().parse(Seq::from_string("name=\"value\""))
  let map = result.unwrap().0
  inspect!(map.size(), content="1")
  inspect!(map.get("name"), content="Some(\"value\")")
}

test "pattributes/single" {
  // Test case for single attribute
  let result = pattributes().parse(
    Seq::from_string("name=\"value\" lang=\"en\""),
  )
  let map = result.unwrap().0
  inspect!(map.size(), content="2")
  inspect!(map.get("name"), content="Some(\"value\")")
}

test "panic pattributes/invalid_format" {
  // Test case for invalid attribute format
  let result = pattributes().parse(Seq::from_string("name=value"))
  inspect!(result, content="None")
}

// 解析 XML 元素
///|
pub fn pelement() -> Parser[Char, XMLElement] {
  let element_ref : Ref[Parser[Char, XMLElement]] = { val: fn { _ => None } }
  let content_ref : Ref[Parser[Char, @queue.T[XMLChildren]]] = {
    val: fn { _ => None },
  }
  fn trim_text(text : String) -> (String, String, String) {
    // text should not be empty
    let seq = Seq::from_string(text)
    let (head_WS, rest) = match pwhite_space().parse(seq) {
      Some((ws, rest)) => (ws, rest)
      None => ("", seq)
    }
    if rest.is_empty() {
      return (head_WS, "", "")
    }
    let seq = Seq::from_string(text.rev())
    let tail_WS = match pwhite_space().parse(seq) {
      Some((ws, _)) => ws.rev()
      None => ""
    }
    let content = text.substring(
      start=head_WS.length(),
      end=text.length() - tail_WS.length(),
    )
    (head_WS, content, tail_WS)
  }

  fn pcontent() -> Parser[Char, @queue.T[XMLChildren]] {
    let element_parser = @combinator.ref(element_ref).map(fn(e) { Element(e) })
    let reference_parser = preference().map(fn(s) { Reference(s) })
    let cdata_parser = pcdata().map(fn(s) { CDATA(s) })
    let pi_parser = ppi().map(fn(pi) { PI(pi) })
    let comment_parser = pcomment().map(fn(s) { Comment(s) })
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
              (head_WS, "", _) => @queue.of([WhiteSpace(head_WS)])
              (head_WS, content, "") =>
                @queue.of([WhiteSpace(head_WS), Text(content)])
              (head_WS, content, tail_WS) =>
                @queue.of([
                  WhiteSpace(head_WS),
                  Text(content),
                  WhiteSpace(tail_WS),
                ])
            }
          None => @queue.new()
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
    .and_then(pwhite_space())
    .omit_second()
    .and_then(pattributes())
    .and_then(@combinator.pstring("/>"))
    .omit_second()
    .map(fn {
      (name, attributes) => { name, attributes, children: @queue.new() }
    })
  content_ref.val = pcontent()
  let children_parser = @combinator.pchar('<')
    .and_then(pname())
    .omit_first()
    .and_then(pwhite_space())
    .omit_second()
    .and_then(pattributes())
    .and_then(@combinator.pchar('>'))
    .omit_second()
    .map(fn(x) { x })
    .and_then(@combinator.ref(content_ref))
    .map(fn(x) { x })
    .and_then(
      @combinator.pstring("</")
      .and_then(pname())
      .omit_first()
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
      { name: name_start, attributes: attrs, children }
    })
  // 这么组合的性能不够好。 
  let parser = empty_parser.or_else(children_parser)
  element_ref.val = parser
  return element_ref.val
}

test "pelement/empty" {
  // Test empty element with no attributes
  let result = pelement().parse(Seq::from_string("<br/>"))
  inspect!(
    result,
    content="Some(({name: \"br\", attributes: {}, children: @queue.of([])}, ))",
  )

  // Test empty element with multiple attributes and special characters
  let result2 = pelement().parse(
    Seq::from_string(
      "<meta name=\"description\" content=\"Test & Demo\" charset=\"UTF-8\"/>",
    ),
  )
  let element = result2.unwrap().0
  inspect!(element.name, content="meta")
  inspect!(element.attributes.get("name"), content="Some(\"description\")")
  inspect!(element.attributes.get("content"), content="Some(\"Test & Demo\")")
  inspect!(element.attributes.get("charset"), content="Some(\"UTF-8\")")
  inspect!(element.children.length(), content="0")
}

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
  let result = pelement().parse(Seq::from_string(xml))
  let element = result.unwrap().0
  // Check root element
  inspect!(element.name, content="root")
  inspect!(element.attributes.get("id"), content="Some(\"main\")")
}

///|
fn peek_char_seq(seq : Seq[Char], n : Int) -> String? {
  // help me return Some(first n char to string) in seq, or return None
  loop n, seq.uncons(), "" {
    _..<0, _, _ => None
    0, _, s => Some(s)
    _, None, _ => None
    n, Some((c, rest)), s => continue n - 1, rest.uncons(), s + c.to_string()
  }
}

///|
pub fn pcdata() -> Parser[Char, String] {
  let ptail_cdata : Parser[Char, String] = fn(seq) {
    let peek3 = peek_char_seq(seq, 3)
    match peek3 {
      Some("]]>") => None
      _ =>
        match seq.uncons() {
          Some((c, rest)) => Some((c.to_string(), rest))
          None => None
        }
    }
  }
  @combinator.pstring("<![CDATA[")
  .and_then(ptail_cdata.repeat())
  .omit_first()
  .and_then(@combinator.pstring("]]>"))
  .omit_second()
  .map(fn { arr => @string.concat(arr, separator="") })
}

///|
pub fn pcomment() -> Parser[Char, String] {
  let ptail_comment : Parser[Char, Char] = fn(seq) {
    let peek3 = peek_char_seq(seq, 3)
    match peek3 {
      Some("-->") => None
      _ =>
        match seq.uncons() {
          Some((c, rest)) => Some((c, rest))
          None => None
        }
    }
  }
  @combinator.pstring("<!--")
  .and_then(ptail_comment.repeat())
  .omit_first()
  .and_then(@combinator.pstring("-->"))
  .omit_second()
  .map(fn {
    chars => chars.fold(init="", fn(str, char) { str + char.to_string() })
  })
}

///|
pub fn ppi() -> Parser[Char, String] {
  let ptail_pi : Parser[Char, Char] = fn(seq) {
    let peek2 = peek_char_seq(seq, 2)
    match peek2 {
      Some("?>") => None
      _ =>
        match seq.uncons() {
          Some((c, rest)) => Some((c, rest))
          None => None
        }
    }
  }
  @combinator.pstring("<?")
  .and_then(ptail_pi.repeat())
  .omit_first()
  .and_then(@combinator.pstring("?>"))
  .omit_second()
  .map(fn {
    chars => chars.fold(init="", fn(str, char) { str + char.to_string() })
  })
}

test "pcomment/empty" {
  // Empty comment
  let result = pcomment().parse(Seq::from_string("<!---->"))
  inspect!(result, content="Some((\"\", ))")
}

test "pcomment/with_content" {
  // Comment with various content including special characters
  let result = pcomment().parse(
    Seq::from_string("<!-- This is a comment with <tags> and &symbols& -->"),
  )
  inspect!(
    result,
    content="Some((\" This is a comment with <tags> and &symbols& \", ))",
  )
}

test "pcomment/invalid" {
  // Incomplete comment
  let result = pcomment().parse(Seq::from_string("<!--"))
  inspect!(result, content="None")

  // Missing opening sequence
  let result2 = pcomment().parse(Seq::from_string("Comment -->"))
  inspect!(result2, content="None")
}

///|
pub fn pEntityRef() -> Parser[Char, String] {
  @combinator.pchar('&')
  .and_then(pname())
  .and_then(@combinator.pchar(';'))
  .map(fn { ((and, name), semicolon) => "&" + name + ";" })
}

///|
pub fn pcharRef() -> Parser[Char, String] {
  let pdecimal = @combinator.pchar('#')
    .and_then(digit)
    .and_then(digit.repeat())
    .and_then(@combinator.pchar(';'))
    .map(fn {
      (((hash, digit), digits), semicolon) =>
        "#" +
        digit.to_string() +
        digits.fold(init="", fn(str, char) { str + char.to_string() }) +
        ";"
    })
  let phex = @combinator.pstring("&#x")
    .and_then(hexdigit)
    .and_then(hexdigit.repeat())
    .and_then(@combinator.pchar(';'))
    .map(fn {
      (((hash, digit), digits), semicolon) =>
        "#" +
        digit.to_string() +
        digits.fold(init="", fn(str, char) { str + char.to_string() }) +
        ";"
    })
  pdecimal.or_else(phex)
}

///|
pub fn preference() -> Parser[Char, String] {
  pEntityRef().or_else(pcharRef())
}

///|
pub fn pprolog() -> Parser[Char, Map[String, String]] {
  @combinator.pstring("<?xml")
  .and_then(pwhite_space())
  .and_then(pattributes())
  .omit_first()
  .and_then(@combinator.pstring("?>"))
  .omit_second()
}

test "pprolog/valid_prolog_with_spaces" {
  let result = pprolog().parse(
    Seq::from_string(
      "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>",
    ),
  )
  inspect!(
    result,
    content="Some(({\"version\": \"1.0\", \"encoding\": \"UTF-8\", \"standalone\": \"yes\"}, ))",
  )
}

test "pprolog/minimal_valid_prolog" {
  let result = pprolog().parse(Seq::from_string("<?xml ?>"))
  inspect!(result, content="Some(({}, ))")
}

///|
pub fn pdtd() -> Parser[Char, String] {
  @combinator.pstring("<!")
  .and_then(@combinator.pchar_such_that(fn(c) { c != '>' }).repeat())
  .omit_first()
  .map(fn(chars) {
    chars.fold(init="", fn(str, char) { str + char.to_string() })
  })
  .and_then(@combinator.pchar('>'))
  .omit_second()
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
///   let result = pxml().parse(Seq::from_string(xml))
///   let doc = result.unwrap().0
///   inspect!(doc.version, content="1.0")
///   inspect!(doc.root.name, content="root")
/// }
/// ```
pub fn pxml() -> Parser[Char, XMLDocument] {
  pwhite_space()
  .and_then(pprolog().optional())
  .omit_first()
  .map(fn(x) { return x })
  .and_then(pdtd().optional())
  .and_then(pwhite_space())
  .omit_second()
  .and_then(pelement())
  .map(fn(tuple) {
    let ((map, dtd), element) = tuple
    let map = match map {
      Some(m) => m
      None => Map::new()
    }
    {
      version: map["version"].or("1.0"),
      encoding: map["encoding"].or("UTF-8"),
      standalone: match map["standalone"] {
        Some("yes") => true
        _ => false
      },
      root: element,
    }
  })
}

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
  let result = pxml().parse(Seq::from_string(xml))
  let doc = result.unwrap().0

  // Check basic document properties
  inspect!(doc.version, content="1.0")
  inspect!(doc.encoding, content="UTF-8")
  inspect!(doc.standalone, content="false")

  // Check root element
  inspect!(doc.root.name, content="root")
  inspect!(doc.root.attributes.get("id"), content="Some(\"main\")")
}

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
  let result = pxml().parse(Seq::from_string(xml))
  let doc = result.unwrap().0
  inspect!(doc.version, content="1.0")
  inspect!(doc.root.name, content="root")

  // Check that root has children
  inspect!(doc.root.children.is_empty(), content="false")
}

test "pxml/basic_xml_no_attributes" {
  let xml = "<root></root>"
  let result = pxml().parse(Seq::from_string(xml))
  let document = result.unwrap().0
  inspect!(document.version, content="1.0")
  inspect!(document.encoding, content="UTF-8")
  inspect!(document.standalone, content="false")
  inspect!(document.root.name, content="root")
  inspect!(document.root.attributes.size(), content="0")
}

test "pxml/basic_xml_with_attributes" {
  let xml = "<?xml version=\"1.1\" encoding=\"ISO-8859-1\" standalone=\"yes\"?><root attr1=\"value1\" attr2=\"value2\"></root>"
  let result = pxml().parse(Seq::from_string(xml))
  let document = result.unwrap().0
  inspect!(document.version, content="1.1")
  inspect!(document.encoding, content="ISO-8859-1")
  inspect!(document.standalone, content="true")
  inspect!(document.root.name, content="root")
  inspect!(document.root.attributes.size(), content="2")
  inspect!(document.root.attributes.get("attr1"), content="Some(\"value1\")")
  inspect!(document.root.attributes.get("attr2"), content="Some(\"value2\")")
}

test "pxml/mismatched_start_end_tags" {
  let xml = "<root><child></root>"
  ignore(pxml().parse(Seq::from_string(xml)))
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
///   let doc = xml_from_string(xml)
///   inspect!(doc?.root.name, content="\"root\"")
/// }
/// ```
pub fn xml_from_string(s : String) -> XMLDocument? {
  let result = pxml().parse(Seq::from_string(s))
  match result {
    Some((doc, _)) => Some(doc)
    None => None
  }
}
