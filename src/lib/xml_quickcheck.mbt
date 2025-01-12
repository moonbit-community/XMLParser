///|
typealias Gen[T] = @qc.Gen[T]

///|
impl @quickcheck.Arbitrary for XMLDocument with arbitrary(size, rs) {
  {
    version: "1.0",
    encoding: "UTF-8",
    standalone: true,
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
    .fold(init=@queue.new(), fn(queue, child) {
      queue.push(child)
      queue
    })
  { name, attributes, children }
}

///|
impl @quickcheck.Arbitrary for XMLChildren with arbitrary(size, rs) {
  let strGen : Gen[String] = Gen::spawn()
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
    not(s.contains("-->"))
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
  match xml2 {
    Some(_) => true
    None => false
  }
}

test "fuzzing" {
  @qc.quick_check_fn!(trivial)
}

test "fail" {
  let str = "<?xml version=\"&$\" encoding=\"eXh4Qc\"\x0fF\x1d[]H\x19A\x00\" standalone=\"true\" ?>\n<vjolNG04hr key_1=\"4\x1cr\x06l\x10dxSa\x10\x01\" key_2=\"<)jxL\x16x\x0bR\x15\x0cw\x1b]w\x00eh\" key_3=\".cXWh$oJfX\x16\x1cY?J\" key_4=\"$f/1\" key_5=\"4Y\" key_6=\"\x0c0N*$\" key_7=\"=\" key_8=\"E;#\" key_9=\"W.\x07t%i\x1eumy\x05'@9\"><![CDATA[]]><X ></X></vjolNG04hr>"
  let option = xml_from_string(str)
  println(option)
}
