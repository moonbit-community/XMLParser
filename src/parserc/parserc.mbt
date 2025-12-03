///|
pub fn[Token, Value] Parser::new(
  f : (Seq[Token]) -> (Value, Seq[Token])?,
) -> Parser[Token, Value] {
  Parser(f)
}

///|
#deprecated("use `Parser::run` instead")
pub fn[Token, Value] Parser::parse(
  self : Parser[Token, Value],
  sequence : Seq[Token],
) -> (Value, Seq[Token])? {
  (self.0)(sequence)
}

///|
/// Parses a sequence of tokens
///
/// If the parsing succeeds, `Some(result, rest)` is returned  
/// Otherwise, `None` is returned.
pub fn[Token, Value] Parser::run(
  self : Parser[Token, Value],
  sequence : Seq[Token],
) -> (Value, Seq[Token])? {
  (self.0)(sequence)
}

///|
pub fn[Token, A, B, C] lift2(
  f : (A, B) -> C,
) -> (Parser[Token, A], Parser[Token, B]) -> Parser[Token, C] {
  fn(pa, pb) { pa.apply(pb.apply(pconst(fn(b) { fn(a) { f(a, b) } }))) }
}

///|
pub fn[Token, A] sequence(
  parsers : Array[Parser[Token, A]],
) -> Parser[Token, Array[A]] {
  Parser(fn(tokens) {
    let result : Array[A] = []
    let mut tokens = Some(tokens)
    parsers.each(fn(parser) {
      match tokens {
        Some(ts) =>
          tokens = parser
            .run(ts)
            .map(fn(tuple) {
              let (hd, tl) = tuple
              result.push(hd)
              tl
            })
        None => ()
      }
    })
    tokens.map(fn(tokens) { (result, tokens) })
  })
}

///|
pub fn[Token, A, B] Parser::and_then(
  self : Parser[Token, A],
  other : Parser[Token, B],
) -> Parser[Token, (A, B)] {
  Parser(fn(tokens) {
    let (a, rest) = match self.run(tokens) {
      None => return None
      Some(s) => s
    }
    let (b, rest2) = match other.run(rest) {
      None => return None
      Some(s) => s
    }
    Some(((a, b), rest2))
  })
}

///|
pub fn[Token, A] Parser::or_else(
  self : Parser[Token, A],
  other : Parser[Token, A],
) -> Parser[Token, A] {
  Parser(fn(tokens) {
    match self.run(tokens) {
      None => other.run(tokens)
      Some(_) as result => result
    }
  })
}

///|
pub fn[Token, A] Parser::or_others(
  self : Parser[Token, A],
  others : ArrayView[Parser[Token, A]],
) -> Parser[Token, A] {
  match others {
    [] => self
    [hd, .. tl] => self.or_else(hd.or_others(tl))
  }
}

///|
pub fn[Token, A, B] Parser::map(
  self : Parser[Token, A],
  f : (A) -> B,
) -> Parser[Token, B] {
  Parser(fn(tokens) {
    let (a, rest) = match self.run(tokens) {
      None => return None
      Some(s) => s
    }
    Some((f(a), rest))
  })
}

///|
pub fn[Token, A, B] Parser::apply(
  self : Parser[Token, A],
  f : Parser[Token, (A) -> B],
) -> Parser[Token, B] {
  self.and_then(f).map(fn(pair) { (pair.1)(pair.0) })
}

///|
pub fn[Token, A] Parser::repeat_n(
  self : Parser[Token, A],
  n : Int,
) -> Parser[Token, Array[A]] {
  self.repeat_n_with_sep(n, pconst(()))
}

///|
pub fn[Token, A, B] Parser::repeat_n_with_sep(
  self : Parser[Token, A],
  n : Int,
  sep : Parser[Token, B],
) -> Parser[Token, Array[A]] {
  if n < 0 {
    pfail()
  } else if n == 0 {
    pconst([])
  } else if n == 1 {
    self.map(fn(v) { Array::make(1, v) })
  } else {
    Parser(fn(seq) {
      let (hd, tl) = match self.run(seq) {
        None => return None
        Some(s) => s
      }
      let array = Array::make(n, hd)
      let parser = sep.and_then(self).omit_first()
      for i = 0, rest = tl; i < n - 1; {
        let (hd, tl) = match parser.run(rest) {
          None => return None
          Some(s) => s
        }
        array[i + 1] = hd
        continue i + 1, tl
      } else {
        Some((array, rest))
      }
    })
  }
}

///|
pub fn[Token, A] Parser::repeat_0_to_n(
  self : Parser[Token, A],
  n : Int,
) -> Parser[Token, Array[A]] {
  self.repeat_0_to_n_with_sep(n, pconst(()))
}

///|
pub fn[Token, A, B] Parser::repeat_0_to_n_with_sep(
  self : Parser[Token, A],
  n : Int,
  separator : Parser[Token, B],
) -> Parser[Token, Array[A]] {
  if n < 0 {
    pfail()
  } else if n == 0 {
    pconst([])
  } else {
    Parser(fn(seq) {
      let sep_self = separator.and_then(self).omit_first()
      match self.run(seq) {
        None => return Some(([], seq))
        Some((hd, tl)) => {
          let result = [hd]
          for i = 0, rest = tl; i < n - 1; {
            match sep_self.run(rest) {
              Some((hd, tl)) => {
                result.push(hd)
                continue i + 1, tl
              }
              None => break Some((result, rest))
            }
          } else {
            Some((result, rest))
          }
        }
      }
    })
  }
}

///|
pub fn[Token, A] Parser::repeat(
  self : Parser[Token, A],
) -> Parser[Token, Array[A]] {
  self.repeat_with_sep(pconst(()))
}

///|
pub fn[Token, A, B] Parser::repeat_with_sep(
  self : Parser[Token, A],
  separator : Parser[Token, B],
) -> Parser[Token, Array[A]] {
  Parser(fn(seq) {
    let sep_self = separator.and_then(self).omit_first()
    match self.run(seq) {
      None => return Some(([], seq))
      Some((hd, tl)) => {
        let result = [hd]
        let input = loop tl {
          input =>
            match sep_self.run(input) {
              Some((hd, tl)) => {
                result.push(hd)
                continue tl
              }
              None => input
            }
        }
        Some((result, input))
      }
    }
  })
}

///|
pub fn[Token, A] Parser::optional(self : Parser[Token, A]) -> Parser[Token, A?] {
  self.map(fn(x) { Some(x) }).or_else(pconst(Option::None))
}

///|
pub fn[Token, A, B] Parser::omit_first(
  parser : Parser[Token, (A, B)],
) -> Parser[Token, B] {
  parser.map(fn(pair) { pair.1 })
}

///|
pub fn[Token, A, B] Parser::omit_second(
  parser : Parser[Token, (A, B)],
) -> Parser[Token, A] {
  parser.map(fn(pair) { pair.0 })
}

///|
pub fn[Token, A, B] Parser::between(
  self : Parser[Token, A],
  around : Parser[Token, B],
) -> Parser[Token, A] {
  around.and_then(self).omit_first().and_then(around).omit_second()
}

///|
pub fn[Token, A] Parser::from_ref(
  self : Ref[Parser[Token, A]],
) -> Parser[Token, A] {
  Parser(fn(str) { self.val.run(str) })
}

///|
pub fn[A : Show] one_of(array : Array[A]) -> Parser[Char, A] {
  array.rev_fold(
    fn(p, i) { pstring(i.to_string()).map(fn(_str) { i }).or_else(p) },
    init=pfail(),
  )
}
