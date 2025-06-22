//This file is mainly to implement parsing DTD (Document Type Decl).

///|
fn pnmtokens() -> Parser[Char, String] {
  @combinator.pchar_such_that(is_name_char)
  .and_then(
    @combinator.pchar_such_that(is_name_char)
    .repeat()
    .map(arr => arr.fold(init="", (str, c) => str + c.to_string())),
  )
  .map(fn(tuple) {
    let (c, str) = tuple
    c.to_string() + str
  })
}

///|
fn ppubidLiteral() -> Parser[Char, String] {
  fn is_pubid_char(c : Char) -> Bool {
    match c {
      '\u0020'
      | '\u000D'
      | 'a'..='z'
      | 'A'..='Z'
      | '0'..='9'
      | '-'
      | '\''
      | '('
      | ')'
      | '+'
      | ','
      | '.'
      | '/'
      | ':'
      | '='
      | '?'
      | ';'
      | '!'
      | '*'
      | '#'
      | '@'
      | '$'
      | '_'
      | '%' => true
      _ => false
    }
  }

  let single_quote = @combinator.pchar('\'')
    .and_then(
      @combinator.pchar_such_that(c => is_pubid_char(c) && c != '\'')
      .repeat()
      .map(arr => arr.fold(init="", (str, c) => str + c.to_string())),
    )
    .and_then(@combinator.pchar('\''))
    .omit_second()
    .map(fn(tuple) {
      let (quote, str) = tuple
      quote.to_string() + str + quote.to_string()
    })
  let double_quote = @combinator.pchar('"')
    .and_then(
      @combinator.pchar_such_that(c => is_pubid_char(c))
      .repeat()
      .map(arr => arr.fold(init="", (str, c) => str + c.to_string())),
    )
    .and_then(@combinator.pchar('"'))
    .omit_second()
    .map(fn(tuple) {
      let (quote, str) = tuple
      quote.to_string() + str + quote.to_string()
    })
  single_quote.or_else(double_quote)
}

///|
fn psystemLiteral() -> Parser[Char, String] {
  fn make_parser(quote : Char) {
    @combinator.pchar(quote)
    .and_then(@combinator.pchar_such_that(fn(c) { c != quote }).repeat())
    .and_then(@combinator.pchar(quote))
    .omit_second()
    .map(fn(tuple) {
      let (quote, arr) = tuple
      arr.fold(init=quote.to_string(), (str, c) => str + c.to_string()) +
      quote.to_string()
    })
  }

  make_parser('\'').or_else(make_parser('"'))
}

///|
fn pPEReference() -> Parser[Char, String] {
  @combinator.pchar('%')
  .and_then(pname())
  .and_then(@combinator.pchar(';'))
  .map(fn(tuple) {
    let ((_and, name), _semicolon) = tuple
    "&" + name + ";"
  })
}

///|
fn pentityValue() -> Parser[Char, String] {
  fn make_parser(quote : Char) {
    @combinator.pchar(quote)
    .and_then(
      @combinator.pchar_such_that(fn(c) { c != quote && c != '%' && c != '&' })
      .map(fn(c) { c.to_string() })
      .or_else(pPEReference())
      .or_else(preference())
      .repeat(),
    )
    .and_then(@combinator.pchar(quote))
    .map(fn(tuple) {
      let ((_, arr), _) = tuple
      arr.fold(init=quote.to_string(), (str, c) => str + c) + quote.to_string()
    })
  }

  let parser = make_parser('\'').or_else(make_parser('"'))
  parser
}

///|
fn pexternalID() -> Parser[Char, ExternalID] {
  let system = @combinator.pstring("SYSTEM")
    .and_then(pwhite_space())
    .and_then(psystemLiteral())
    .omit_first()
    .map(fn(str) { System(str) })
  let public = @combinator.pstring("PUBLIC")
    .and_then(pwhite_space())
    .and_then(ppubidLiteral())
    .omit_first()
    .and_then(pwhite_space())
    .omit_second()
    .and_then(psystemLiteral())
    .map(fn(tuple) {
      let (pubid, system) = tuple
      Public(pubid, system)
    })
  public.or_else(system)
}

///|
fn ppublicID() -> Parser[Char, String] {
  @combinator.pstring("PUBLIC")
  .and_then(pwhite_space())
  .and_then(ppubidLiteral())
  .omit_first()
}

///|
fn pentityDecl() -> Parser[Char, EntityDecl] {
  let pNDataDecl = pwhite_space()
    .and_then(@combinator.pstring("NDATA"))
    .and_then(pwhite_space())
    .and_then(pname())
    .omit_first()
  let pGEDecl = @combinator.pstring("<!ENTITY")
    .and_then(pwhite_space())
    .and_then(pname())
    .omit_first()
    .and_then(pwhite_space())
    .omit_second()
    .and_then(
      pentityValue()
      .map(fn(str) { EntityValue(str) })
      .or_else(
        pexternalID()
        .and_then(pNDataDecl.optional())
        .map(fn(tuple) {
          let (external_id, ndata) = tuple
          GExternalID(external_id, ndata)
        }),
      ),
    )
    .and_then(pwhite_space().optional())
    .omit_second()
    .and_then(@combinator.pstring(">"))
    .omit_second()
    .map(fn(tuple) {
      let (name, value) = tuple
      GEDecl(name, value)
    })
  let pPEDecl = @combinator.pstring("<!ENTITY")
    .and_then(pwhite_space())
    .and_then(@combinator.pchar('%'))
    .and_then(pwhite_space())
    .and_then(pname())
    .omit_first()
    .and_then(pwhite_space())
    .omit_second()
    .and_then(
      pentityValue()
      .map(fn(str) { EntityValue(str) })
      .or_else(pexternalID().map(fn(external_id) { PExternalID(external_id) })),
    )
    .and_then(pwhite_space().optional())
    .omit_second()
    .and_then(@combinator.pstring(">"))
    .omit_second()
    .map(fn(tuple) {
      let (name, value) = tuple
      PEDecl(name, value)
    })
  pGEDecl.or_else(pPEDecl)
}

///|
test "EnitytDecl" {
  //   <!ENTITY Pub-Status "This is a pre-release of the
  //  specification.">
  // <!ENTITY open-hatch
  //          SYSTEM "http://www.textuality.com/boilerplate/OpenHatch.xml">
  // <!ENTITY open-hatch
  //          PUBLIC "-//Textuality//TEXT Standard open-hatch boilerplate//EN"
  //          "http://www.textuality.com/boilerplate/OpenHatch.xml">
  // <!ENTITY hatch-pic
  //          SYSTEM "../grafix/OpenHatch.gif"
  //          NDATA gif >
  let str =
    #|<!ENTITY Pub-Status "This is a pre-release of the
    #|specification.">
  let seq = Seq::from_string(str)
  let parser = pentityDecl()
  let result = parser.run(seq).unwrap().0
  inspect(result, content=str)
  let str =
    #|<!ENTITY open-hatch
    #|         SYSTEM "http://www.textuality.com/boilerplate/OpenHatch.xml">
  let seq = Seq::from_string(str)
  let parser = pentityDecl()
  let _result = parser.run(seq).unwrap().0
  let str =
    #|<!ENTITY open-hatch
    #|         PUBLIC "-//Textuality//TEXT Standard open-hatch boilerplate//EN"
    #|         "http://www.textuality.com/boilerplate/OpenHatch.xml">
  let seq = Seq::from_string(str)
  let parser = pentityDecl()
  let _result = parser.run(seq).unwrap().0
  let str =
    #|<!ENTITY hatch-pic
    #|         SYSTEM "../grafix/OpenHatch.gif"
    #|         NDATA gif >
  let seq = Seq::from_string(str)
  let parser = pentityDecl()
  let _result = parser.run(seq).unwrap().0

}

///|
fn pelementDecl() -> Parser[Char, ElementDecl] {
  let cp_ref : Ref[Parser[Char, ContentParticle]] = Ref::new(
    @combinator.pfail(),
  )
  let choice = @combinator.pchar('(')
    .and_then(pwhite_space().optional())
    .and_then(Parser::from_ref(cp_ref))
    .omit_first()
    .and_then(
      pwhite_space()
      .optional()
      .and_then(@combinator.pchar('|'))
      .and_then(pwhite_space().optional())
      .and_then(Parser::from_ref(cp_ref))
      .omit_first()
      .repeat(),
    )
    .and_then(pwhite_space().optional())
    .omit_second()
    .and_then(@combinator.pchar(')'))
    .omit_second()
    .map(fn(tuple) {
      let (cp, arr) = tuple
      arr.insert(0, cp)
      arr
    })
  let seq = @combinator.pchar('(')
    .and_then(pwhite_space().optional())
    .and_then(Parser::from_ref(cp_ref))
    .omit_first()
    .and_then(
      pwhite_space()
      .optional()
      .and_then(@combinator.pchar(','))
      .and_then(pwhite_space().optional())
      .and_then(Parser::from_ref(cp_ref))
      .omit_first()
      .repeat(),
    )
    .and_then(pwhite_space().optional())
    .omit_second()
    .and_then(@combinator.pchar(')'))
    .omit_second()
    .map(fn(tuple) {
      let (cp, arr) = tuple
      arr.insert(0, cp)
      arr
    })
  let cp = pname()
    .map(fn(s) { Name(s) })
    .or_else(choice.map(fn(arr) { Choice(arr) }))
    .or_else(seq.map(fn(arr) { Seq(arr) }))
    .and_then(
      @combinator.pchar_such_that(ch => ch == '*' || ch == '+' || ch == '?').optional(),
    )
    .map(fn(tuple) {
      let (cp, ch) = tuple
      let pair = match ch {
        Some('*') => (cp, Some(ZeroOrMore))
        Some('+') => (cp, Some(OneOrMore))
        Some('?') => (cp, Some(Optional))
        None => (cp, None)
        _ => abort("unreachable")
      }
      ContentParticle(pair)
    })
  cp_ref.val = cp
  let children : Parser[Char, ChildrenContentSpec] = choice
    .map(fn(arr) { Choice(arr) })
    .or_else(seq.map(fn(arr) { Seq(arr) }))
    .and_then(
      @combinator.pchar_such_that(ch => ch == '*' || ch == '+' || ch == '?').optional(),
    )
    .map(fn(tuple) {
      let (cp, ch) = tuple
      let pair = match ch {
        Some('*') => (cp, Some(ZeroOrMore))
        Some('+') => (cp, Some(OneOrMore))
        Some('?') => (cp, Some(Optional))
        None => (cp, None)
        _ => abort("unreachable")
      }
      ContentParticle(pair)
    })
  let mixed = @combinator.pstring("(")
    .and_then(pwhite_space().optional())
    .and_then(@combinator.pstring("#PCDATA"))
    .and_then(pwhite_space().optional())
    .and_then(@combinator.pstring(")"))
    .map(fn(_tuple) { Mixed([]) })
    .or_else(
      @combinator.pstring("(")
      .and_then(pwhite_space().optional())
      .and_then(@combinator.pstring("#PCDATA"))
      .and_then(
        pwhite_space()
        .optional()
        .and_then(@combinator.pchar('|'))
        .and_then(pwhite_space().optional())
        .and_then(pname())
        .omit_first()
        .repeat(),
      )
      .omit_first()
      .and_then(pwhite_space().optional())
      .omit_second()
      .and_then(@combinator.pstring(")*"))
      .omit_second()
      .map(fn(arr) { Mixed(arr) }),
    )
  let contentspec = @combinator.pstring("EMPTY")
    .map(fn(_s) { EMPTY })
    .or_else(@combinator.pstring("ANY").map(fn(_s) { ANY }))
    .or_else(mixed)
    .or_else(children.map(fn(child) { Children(child) }))
  let parser = @combinator.pstring("<!ELEMENT")
    .and_then(pwhite_space())
    .and_then(pname())
    .omit_first()
    .and_then(pwhite_space())
    .omit_second()
    .and_then(contentspec)
    .and_then(pwhite_space().optional())
    .omit_second()
    .and_then(@combinator.pstring(">"))
    .omit_second()
    .map(fn(tuple) {
      let (name, content_spec) = tuple
      // println(tuple)
      { name, content_spec }
    })
  return parser
}

///|
test "ElementDecl" {
  // <!ELEMENT br EMPTY>
  // <!ELEMENT p (#PCDATA|emph)* >
  // <!ELEMENT %name.para; %content.para; > don't support 
  // <!ELEMENT container ANY>
  // <!ELEMENT spec (front, body, back?)>
  // <!ELEMENT div1 (head, (p | list | note)*, div2*)>
  // <!ELEMENT dictionary-body (%div.mix; | %dict.mix;)*>
  // <!ELEMENT p (#PCDATA|a|ul|b|i|em)*>
  // <!ELEMENT p (#PCDATA | %font; | %phrase; | %special; | %form;)* >
  // <!ELEMENT b (#PCDATA)>
  let str =
    #|<!ELEMENT br EMPTY>
  let seq = Seq::from_string(str)
  let parser = pelementDecl()
  let result = parser.run(seq).unwrap().0
  inspect(result, content=str)
  inspect(result.name, content="br")
  let str =
    #|<!ELEMENT p (#PCDATA|emph)*>
  let seq = Seq::from_string(str)
  let parser = pelementDecl()
  let result = parser.run(seq).unwrap().0
  inspect(result, content=str)

  // let str = #|<!ELEMENT %name.para; %content.para; >
  // let seq = Seq::from_string(str)
  // let result = parser.run(seq).unwrap().0
  // println(result)

  let str =
    #|<!ELEMENT container ANY>
  let seq = Seq::from_string(str)
  let parser = pelementDecl()
  let result = parser.run(seq).unwrap().0
  inspect(result, content=str)
  let str =
    #|<!ELEMENT spec (front, body, back?)>
  let seq = Seq::from_string(str)
  let parser = pelementDecl()
  let result = parser.run(seq).unwrap().0
  inspect(result.name, content="spec")
  inspect(result, content=str)
  let str =
    #|<!ELEMENT div1 (head, (p | list | note)*, div2*)>
  let seq = Seq::from_string(str)
  let parser = pelementDecl()
  let result = parser.run(seq).unwrap().0
  inspect(result.name, content="div1")
  inspect(result, content=str)

  // let str = #|<!ELEMENT dictionary-body (%div.mix; | %dict.mix;)*>
  // let seq = Seq::from_string(str)
  // let parser = pelementDecl()
  // let result = parser.run(seq).unwrap().0
  // println(result)

  let str =
    #|<!ELEMENT p (#PCDATA|a|ul|b|i|em)*>
  let seq = Seq::from_string(str)
  let parser = pelementDecl()
  let result = parser.run(seq).unwrap().0
  inspect(result.name, content="p")
  inspect(result, content=str)

  // let str = #|<!ELEMENT p (#PCDATA | %font; | %phrase; | %special; | %form;)* >
  // let seq = Seq::from_string(str)
  // let parser = pelementDecl()
  // let result = parser.run(seq).unwrap().0
  // println(result)

  let str =
    #|<!ELEMENT b (#PCDATA)>
  let seq = Seq::from_string(str)
  let parser = pelementDecl()
  let result = parser.run(seq).unwrap().0
  inspect(result.name, content="b")
  inspect(result, content=str)

  // let str = #|<!ELEMENT p (#PCDATA | %font; | %phrase; | %special; | %form;)* >
  // let seq = Seq::from_string(str)
  // let parser = pelementDecl()
  // let result = parser.run(seq).unwrap().0
  // println(result)
}

///|
fn pattListDecl() -> Parser[Char, AttlistDecl] {
  fn pattType() -> Parser[Char, AttType] {
    let notationType = @combinator.pstring("NOTATION")
      .and_then(pwhite_space())
      .and_then(@combinator.pchar('('))
      .and_then(pwhite_space().optional())
      .and_then(pname())
      .omit_first()
      .and_then(
        pwhite_space()
        .optional()
        .and_then(@combinator.pchar('|'))
        .and_then(pwhite_space().optional())
        .and_then(pname())
        .omit_first()
        .repeat(),
      )
      .and_then(pwhite_space().optional())
      .omit_second()
      .and_then(@combinator.pchar(')'))
      .omit_second()
      .map(fn(tuple) {
        let (str, arr) = tuple
        arr.insert(0, str)
        NotationType(arr)
      })
    let enumeration = @combinator.pchar('(')
      .and_then(pwhite_space().optional())
      .and_then(pnmtokens())
      .omit_first()
      .and_then(
        pwhite_space()
        .optional()
        .and_then(@combinator.pchar('|'))
        .and_then(pwhite_space().optional())
        .and_then(pnmtokens())
        .omit_first()
        .repeat(),
      )
      .and_then(pwhite_space().optional())
      .omit_second()
      .and_then(@combinator.pchar(')'))
      .omit_second()
      .map(fn(tuple) {
        let (str, arr) = tuple
        arr.insert(0, str)
        Enumeration(arr)
      })
    let stringType = @combinator.pstring("CDATA").map(fn(str) {
      StringType(str)
    })
    let tokenizedType = @combinator.pstring("IDREFS")
      .or_else(@combinator.pstring("IDREF"))
      .or_else(@combinator.pstring("ID"))
      .or_else(@combinator.pstring("ENTITY"))
      .or_else(@combinator.pstring("ENTITIES"))
      .or_else(@combinator.pstring("NMTOKENS"))
      .or_else(@combinator.pstring("NMTOKEN"))
      .map(fn(str) { TokenizedType(str) })
    let attType = stringType
      .or_else(tokenizedType)
      .or_else(notationType)
      .or_else(enumeration)
    attType
  }

  fn pdefaultDecl() -> Parser[Char, DefaultDecl] {
    let required = @combinator.pstring("#REQUIRED").map(fn(_str) { Required })
    let implied = @combinator.pstring("#IMPLIED").map(fn(_str) { Implied })
    let fixed = @combinator.pstring("#FIXED")
      .and_then(pwhite_space())
      .and_then(pattValue())
      .map(fn(tuple) {
        let (_, str) = tuple
        Fixed(str)
      })
    let value = pattValue().map(fn(str) { Value(str) })
    required.or_else(implied).or_else(fixed).or_else(value)
  }

  let pattDef = pwhite_space()
    .and_then(pname())
    .omit_first()
    .and_then(pwhite_space())
    .omit_second()
    .and_then(pattType())
    .and_then(pwhite_space())
    .omit_second()
    .and_then(pdefaultDecl())
    .map(fn(tuple) {
      let ((name, att_type), default_decl) = tuple
      { name, att_type, default_decl }
    })
  let parser = @combinator.pstring("<!ATTLIST")
    .and_then(pwhite_space())
    .and_then(pname())
    .omit_first()
    .and_then(pattDef.repeat())
    .and_then(pwhite_space().optional())
    .omit_second()
    .and_then(@combinator.pstring(">"))
    .omit_second()
    .map(fn(tuple) {
      let (name, att_defs) = tuple
      { name, att_defs }
    })
  parser
}

///|
test "attListDecl" {
  // <!ATTLIST termdef
  //           id      ID      #REQUIRED
  //           name    CDATA   #IMPLIED>
  // <!ATTLIST list
  //           type    (bullets|ordered|glossary)  "ordered">
  // <!ATTLIST form
  //           method  CDATA   #FIXED "POST">

  let parser = pattListDecl()
  let str =
    #|<!ATTLIST doc a1 NMTOKENS #IMPLIED>
  let seq = Seq::from_string(str)
  let result = parser.run(seq).unwrap()
  let str =
    #|<!ATTLIST termdef
    #|      id      ID      #REQUIRED
    #|      name    CDATA   #IMPLIED>
  let seq = Seq::from_string(str)
  let result = parser.run(seq).unwrap().0
  inspect(result.name, content="termdef")
  let str =
    #|<!ATTLIST list
    #|      type    (bullets|ordered|glossary)  "ordered">
  let seq = Seq::from_string(str)
  let result = parser.run(seq).unwrap().0
  inspect(result.name, content="list")
  let str =
    #|<!ATTLIST form
    #|      method  CDATA   #FIXED "POST">
  let seq = Seq::from_string(str)
  let result = parser.run(seq).unwrap().0
  inspect(result.name, content="form")
  let str =
    #|<!ATTLIST poem  xml:space (default|preserve) 'preserve'>
  let seq = Seq::from_string(str)
  let result = parser.run(seq).unwrap().0
  inspect(result.name, content="poem")
  let str =
    #|<!ATTLIST pre xml:space (preserve) #FIXED 'preserve'>
  let seq = Seq::from_string(str)
  let result = parser.run(seq).unwrap().0
  inspect(result.name, content="pre")
}

///|
fn pnotationDecl() -> Parser[Char, NotationDecl] {
  @combinator.pstring("<!NOTATION")
  .and_then(pwhite_space())
  .and_then(pname())
  .omit_first()
  .and_then(pwhite_space())
  .omit_second()
  .and_then(
    pexternalID()
    .map(fn(external_id) { ExternalID(external_id) })
    .or_else(ppublicID().map(fn(pubid) { PublicID(pubid) })),
  )
  .and_then(pwhite_space().optional())
  .omit_second()
  .and_then(@combinator.pstring(">"))
  .omit_second()
  .map(fn(tuple) {
    let (name, id) = tuple
    { name, id }
  })
}

///|
test "NotationDecl" {
  // <!NOTATION GIF PUBLIC "-//Compuserve//DTD GIF 89a//EN">
  // <!NOTATION JPEG SYSTEM "image_viewer.exe">
  let str =
    #|<!NOTATION GIF PUBLIC "-//Compuserve//DTD GIF 89a//EN">
  let seq = Seq::from_string(str)
  let parser = pnotationDecl()
  let result = parser.run(seq).unwrap().0
  inspect(result, content=str)
  let str =
    #|<!NOTATION JPEG SYSTEM "image_viewer.exe">
  let seq = Seq::from_string(str)
  let parser = pnotationDecl()
  let result = parser.run(seq).unwrap().0
  inspect(result, content=str)
}

///|
fn pmarkupDecl() -> Parser[Char, MarkUpDecl] {
  pattListDecl()
  .map(fn(attlist) { AttListDecl(attlist) })
  .or_else(pelementDecl().map(fn(element) { ElementDecl(element) }))
  .or_else(pentityDecl().map(fn(entity) { EntityDecl(entity) }))
  .or_else(pnotationDecl().map(fn(notation) { NotationDecl(notation) }))
  .or_else(ppi().map(fn(pi) { MarkUpDecl::PI(pi) }))
  .or_else(pcomment().map(fn(comment) { MarkUpDecl::Comment(comment) }))
}

///|
fn pinternalSubset() -> Parser[Char, Array[DTDStatement]] {
  let declSep = pPEReference().or_else(pwhite_space()).map(fn(s) { Sep(s) })
  let parser = pmarkupDecl()
    .map(fn(decl) { Decl(decl) })
    .or_else(declSep)
    .repeat()
  parser
}

///|
fn pmisc() -> Parser[Char, Misc] {
  pcomment()
  .map(fn(comment) { Misc::Comment(comment) })
  .or_else(ppi().map(fn(pi) { Misc::PI(pi) }))
  .or_else(pwhite_space().map(fn(s) { Misc::WhiteSpace(s) }))
}
