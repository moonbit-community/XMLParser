///|
typealias Gen[T] = @qc.Gen[T]

///|
impl @quickcheck.Arbitrary for XMLDocument with arbitrary(size, rs) {
  {
    version: "1.0",
    encoding: "UTF-8",
    standalone: true,
    dtd: None,
    root: Gen::spawn().run(size, rs),
  }
}

///|
impl @quickcheck.Arbitrary for XMLElement with arbitrary(size, rs) {
  let charGen : @qc.Gen[Char] = Gen::spawn()
  let name = charGen.such_that(is_name_start_char).run(size, rs).to_string() +
    charGen
    .such_that(is_name_char)
    .array_with_size(size - 1)
    .run(size - 1, rs)
    .iter()
    .fold(init="", fn(s, c) { s + c.to_string() })
  fn is_value(s : String) -> Bool {
    not(s.contains("\""))
  }

  let iterGen : @qc.Gen[Array[String]] = Gen::spawn()
    .such_that(is_value)
    .array_with_size(size)
  let attributes = iterGen
    .run(size, rs)
    .fold(init=Map::new(), fn(map, value) {
      map.set("key_\{map.size()+1}", value)
      map
    })
  let childrenGen : @qc.Gen[Iter[XMLChildren]] = Gen::spawn()
  let children = childrenGen
    .run(size, rs)
    .fold(init=[], fn(queue, child) {
      queue.push(child)
      queue
    })
  let emptyGen : @qc.Gen[Bool] = @qc.one_of([@qc.pure(true), @qc.pure(false)])
  let empty_element = if children.is_empty() {
    emptyGen.run(size, rs)
  } else {
    false
  }
  { name, empty_element, attributes, children }
}

///|
impl @quickcheck.Arbitrary for XMLChildren with arbitrary(size, rs) {
  fn valid_string(s: String) -> Bool {
    s.iter().all(fn(c) { is_char(c)})
  }
  let strGen : Gen[String] = Gen::spawn().such_that(valid_string)
  let refGen : Gen[String] = Gen::new(fn(size, rs) {
    let charGen : @qc.Gen[Char] = Gen::spawn()
    let name = charGen.such_that(is_name_start_char).run(size, rs).to_string() +
      charGen
      .such_that(is_name_char)
      .array_with_size(size - 1)
      .run(size - 1, rs)
      .iter()
      .fold(init="", fn(s, c) { s + c.to_string() })
    "&" + name + ";"
  })
  let wsGen : Gen[String] = @qc.one_of([
      @qc.pure(" "),
      @qc.pure("\t"),
      @qc.pure("\r"),
      @qc.pure("\n"),
    ])
    .array_with_size(size)
    .fmap(fn(arr) { @string.concat(arr, separator="") })
  let elementGen : Gen[XMLElement] = Gen::spawn()
  //Element(XMLElement)
  //Reference(String)
  //CDATA(String)
  //PI(String)
  //Comment(String)
  //Text(String)
  //WhiteSpace(String)

  // TODO :  按照实际的内容生成
  fn is_text(s : String) -> Bool {
    not(s.contains("&") || s.contains("<"))
  }

  fn is_cdata(s : String) -> Bool {
    not(s.contains("]]>"))
  }

  fn is_PI(s : String) -> Bool {
    not(s.contains("?>"))
  }

  fn is_comment(s : String) -> Bool {
    not(s.ends_with("-")) && not(s.contains("-->"))
  }

  let childGen : Gen[XMLChildren] = @qc.one_of([
    refGen.fmap(fn(s) { Reference(s) }),
    strGen.such_that(is_cdata).fmap(fn(s) { CDATA(s) }),
    strGen.such_that(is_PI).fmap(fn(s) { PI(s) }),
    strGen.such_that(is_comment).fmap(fn(s) { Comment(s) }),
    strGen.such_that(is_text).fmap(fn(s) { Text(s) }),
    wsGen.fmap(fn(s) { WhiteSpace(s) }),
    elementGen.fmap(fn(e) { Element(e) }).resize(size - 1), // limit nesting depth
  ])
  childGen.run(size, rs)
}

///|
fn trivial(xml : XMLDocument) -> Bool {
  let s = xml.to_string()
  let xml2 = xml_from_string(s)
  not(xml2.is_empty())
}

///|
fn trivial_iter(xml : XMLDocument) -> Bool {
  let s = xml.to_string()
  let xml2 = xml_from_iter(s.iter())
  not(xml2.is_empty())
}

///|
fn trivial_ctx(xml : XMLDocument) -> Bool {
  let s = xml.to_string()
  let (xml2, ctx) = xml_from_string_with_ctx(s)
  if not(ctx.errors.is_empty()) {
    println(ctx.errors)
  }
  let flag = ctx.errors
    .filter(fn {
      e =>
        match e.kind {
          InternalParserError => true
          _ => false
        }
    })
    .is_empty()
  if xml2.is_empty() {
    return false
  }
  flag
}

///|
test "fuzzing" {
  @qc.quick_check_fn!(trivial)
  @qc.quick_check_fn!(trivial_iter)
  @qc.quick_check_fn!(trivial_ctx)
}
