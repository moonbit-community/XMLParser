///|
using @quickcheck {type Generator}

///|
/// Values of `g` that satisfy `pred` (`Gen::such_that` in quickcheck 0.14,
/// which the core generators do not have). Same retry schedule: at size `n`
/// try the sizes `n ..= 2n`, then start over at size `n + 1`.
fn[T] such_that(g : Generator[T], pred : (T) -> Bool) -> Generator[T] {
  Generator((size, state) => {
    for n = size, state = state {
      let next_round = state.split()
      for m = n, state = state; m <= 2 * n; {
        let next_try = state.split()
        let x = g.run(m, state)
        if pred(x) {
          return x
        }
        continue m + 1, next_try
      }
      continue n + 1, next_round
    }
  })
}

///|
/// `n` independent values of `g`, and none when `n` is negative: nested
/// elements are generated at `size - 1`, which goes below zero, and core's
/// `array_with_size` aborts there (quickcheck 0.14 returned an empty array).
fn[T] array_of(g : Generator[T], n : Int32) -> Generator[Array[T]] {
  g.array_with_size(if n < 0 { 0 } else { n })
}

///|
impl @shrink.Shrink for XMLDocument with fn shrink(self) {
  [].iter()
}

///|
impl @quickcheck.Arbitrary for XMLDocument with fn arbitrary(size, rs) {
  {
    version: "1.0",
    encoding: "UTF-8",
    standalone: true,
    dtd: None,
    root: @quickcheck.spawn().run(size, rs),
  }
}

///|
impl @quickcheck.Arbitrary for XMLElement with fn arbitrary(size, rs) {
  let charGen : Generator[Char] = @quickcheck.spawn()
  let name = such_that(charGen, is_name_start_char).run(size, rs).to_string() +
    array_of(such_that(charGen, is_name_char), size - 1)
    .run(size - 1, rs)
    .iter()
    .fold(init="", fn(s, c) { s + c.to_string() })
  fn is_value(s : String) -> Bool {
    !(s.contains("\"") || s.contains("<") || s.contains("&"))
  }

  let iterGen : Generator[Array[String]] = array_of(
    such_that(@quickcheck.spawn(), is_value),
    size,
  )
  let attributes = iterGen
    .run(size, rs)
    .fold(init=Map([]), fn(map, value) {
      map.set("key_\{map.length()+1}", value)
      map
    })
  let childrenGen : Generator[Iter[XMLChildren]] = @quickcheck.spawn()
  let children = childrenGen
    .run(size, rs)
    .fold(init=[], fn(queue, child) {
      queue.push(child)
      queue
    })
  let emptyGen : Generator[Bool] = @quickcheck.one_of([
    @quickcheck.pure(true),
    @quickcheck.pure(false),
  ])
  let empty_element = if children.is_empty() {
    emptyGen.run(size, rs)
  } else {
    false
  }
  { name, empty_element, attributes, children, }
}

///|
impl @quickcheck.Arbitrary for XMLChildren with fn arbitrary(size, rs) {
  fn valid_string(s : String) -> Bool {
    s.iter().all(fn(c) { is_char(c) })
  }

  let strGen : Generator[String] = such_that(@quickcheck.spawn(), valid_string)
  let refGen : Generator[String] = Generator(fn(size, rs) {
    let charGen : Generator[Char] = @quickcheck.spawn()
    let name = such_that(charGen, is_name_start_char).run(size, rs).to_string() +
      array_of(such_that(charGen, is_name_char), size - 1)
      .run(size - 1, rs)
      .iter()
      .fold(init="", fn(s, c) { s + c.to_string() })
    "&" + name + ";"
  })
  let wsGen : Generator[String] = array_of(
    @quickcheck.one_of([
      @quickcheck.pure(" "),
      @quickcheck.pure("\t"),
      @quickcheck.pure("\r"),
      @quickcheck.pure("\n"),
    ]),
    size,
  ).map(arr => arr.join(""))
  let elementGen : Generator[XMLElement] = @quickcheck.spawn()
  //Element(XMLElement)
  //Reference(String)
  //CDATA(String)
  //PI(String)
  //Comment(String)
  //Text(String)
  //WhiteSpace(String)

  // TODO :  按照实际的内容生成
  fn is_text(s : String) -> Bool {
    !(s.contains("&") || s.contains("<"))
  }

  fn is_cdata(s : String) -> Bool {
    !s.contains("]]>")
  }

  fn is_PI(s : String) -> Bool {
    !s.contains("?>")
  }

  fn is_comment(s : String) -> Bool {
    !s.has_suffix("-") && !s.contains("-->")
  }

  let childGen : Generator[XMLChildren] = @quickcheck.one_of([
    refGen.map(fn(s) { Reference(s) }),
    such_that(strGen, is_cdata).map(fn(s) { CDATA(s) }),
    such_that(strGen, is_PI).map(fn(s) { XMLChildren::PI(s) }),
    such_that(strGen, is_comment).map(fn(s) { XMLChildren::Comment(s) }),
    such_that(strGen, is_text).map(fn(s) { Text(s) }),
    wsGen.map(fn(s) { XMLChildren::WhiteSpace(s) }),
    elementGen.map(fn(e) { Element(e) }).resize(size - 1), // limit nesting depth
  ])
  childGen.run(size, rs)
}

///|
fn trivial(xml : XMLDocument) -> Bool {
  let s = xml.to_string()
  let xml2 = xml_from_string(s)
  !(xml2 is None)
}

///|
fn trivial_iter(xml : XMLDocument) -> Bool {
  let s = xml.to_string()
  let xml2 = xml_from_iter(s.iter())
  !(xml2 is None)
}

///|
fn trivial_ctx(xml : XMLDocument) -> Bool {
  let s = xml.to_string()
  let (xml2, ctx) = xml_from_string_with_ctx(s)
  if !ctx.errors.is_empty() {
    println(Repr(ctx.errors))
  }
  let flag = ctx.errors
    .filter(e => {
      match e.kind {
        InternalParserError => true
        _ => false
      }
    })
    .is_empty()
  if xml2 is None {
    return false
  }
  flag
}

///|
test "fuzzing" {
  // `max_size=99` keeps the sizes 0, 1, ..., 99 that `quick_check_fn` used.
  @quickcheck.check(trivial, max_size=99)
  @quickcheck.check(trivial_iter, max_size=99)
  @quickcheck.check(trivial_ctx, max_size=99)
}
