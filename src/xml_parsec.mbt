///| 接收Seq[Token]和XMLParserContext，返回((Value, Seq[Token])?, XMLParseError, XMLParserContext)
/// 这里我们考虑单个Parser最多产生一个Error，同时Paser可能在遇到错误后继续解析（例如dtd检查不通过时）。
/// XMLParser需要在遇到格式错误时立刻停止解析。
pub(all) type XMLParser[Token, Value] (Seq[Token], XMLParserContext) -> (
  (Value, Seq[Token])?,
  XMLParseError?,
  XMLParserContext,
)

///|
typealias XMLParserResult[Token, Value] = (
  (Value, Seq[Token])?,
  XMLParseError?,
  XMLParserContext,
)

///|
pub fn XMLParser::new[Token, Value](
  f : (Seq[Token], XMLParserContext) -> XMLParserResult[Token, Value]
) -> XMLParser[Token, Value] {
  f
}

///|
pub fn XMLParser::run[Token, Value](
  self : XMLParser[Token, Value],
  seq : Seq[Token],
  ctx : XMLParserContext
) -> XMLParserResult[Token, Value] {
  match (self._)(seq, ctx) {
    (pair, Some(err), ctx) => {
      ctx.raise_error(err)
      (pair, Some(err), ctx)
    }
    tuple => tuple
  }
  // (self._)(seq, ctx)
}

///|
pub fn XMLParser::and_then[Token, A, B](
  self : XMLParser[Token, A],
  other : XMLParser[Token, B]
) -> XMLParser[Token, (A, B)] {
  fn(tokens : Seq[Token], ctx : XMLParserContext) {
    let (pair, ctx1) = match self.run(tokens, ctx) {
      (pair, Some(err), ctx1) =>
        if err.is_fatal() {
          (None, ctx1)
        } else {
          (pair, ctx1)
        }
      (pair, _, ctx1) => (pair, ctx1)
    }
    match pair {
      None => return (None, None, ctx1)
      Some((v1, rest)) =>
        match other.run(rest, ctx1) {
          (pair, err, ctx2) =>
            match pair {
              None => (None, err, ctx2)
              Some((v2, rest2)) => (Some(((v1, v2), rest2)), err, ctx2)
            }
        }
    }
  }
}

///|
pub fn XMLParser::or_else[Token, A](
  self : XMLParser[Token, A],
  other : XMLParser[Token, A]
) -> XMLParser[Token, A] {
  fn(tokens : Seq[Token], ctx : XMLParserContext) {
    match self.run(tokens, ctx) {
      (pair, err, ctx1) =>
        match err {
          Some(e) =>
            if e.is_fatal() {
              other.run(tokens, ctx1)
            } else {
              (pair, err, ctx1)
            }
          _ => (pair, err, ctx1)
        }
    }
  }
}

///|
pub fn XMLParser::map[Token, A, B](
  self : XMLParser[Token, A],
  f : (A) -> B
) -> XMLParser[Token, B] {
  fn(tokens : Seq[Token], ctx : XMLParserContext) {
    match self.run(tokens, ctx) {
      (None, err, ctx1) => (None, err, ctx1)
      (Some((v, rest)), err, ctx1) => (Some((f(v), rest)), err, ctx1)
    }
  }
}

///|
pub fn XMLParser::repeat_with_sep[Token, A, B](
  self : XMLParser[Token, A],
  sep : XMLParser[Token, B]
) -> XMLParser[Token, Array[A]] {
  fn(tokens : Seq[Token], ctx : XMLParserContext) {
    let sep_self = sep.and_then(self).omit_first()
    match self.run(tokens, ctx) {
      (None, err, ctx1) =>
        match err {
          Some(e) =>
            if e.is_fatal() {
              (None, err, ctx1)
            } else {
              (Some(([], tokens)), err, ctx1)
            }
          _ => (Some(([], tokens)), err, ctx1)
        }
      (Some((hd, tl)), err, ctx1) => {
        let result = [hd]
        let (input, ctx2) = loop tl, ctx1 {
          input, ctx_loop =>
            match sep_self.run(input, ctx_loop) {
              (Some((hd, tl)), err, ctx2) => {
                result.push(hd)
                continue tl, ctx2
              }
              (None, err, ctx2) => (input, ctx2)
            }
        }
        (Some((result, input)), err, ctx2)
      }
    }
  }
}

///|
pub fn XMLParser::optional[Token, A](
  self : XMLParser[Token, A]
) -> XMLParser[Token, A?] {
  self.map(@option.some).or_else(pconst(Option::None))
}

///|
pub fn XMLParser::omit_first[Token, A, B](
  self : XMLParser[Token, (A, B)]
) -> XMLParser[Token, B] {
  self.map(fn(pair) { pair.1 })
}

///|
pub fn XMLParser::omit_second[Token, A, B](
  self : XMLParser[Token, (A, B)]
) -> XMLParser[Token, A] {
  self.map(fn(pair) { pair.0 })
}

///|
pub fn XMLParser::from_ref[Token, A](
  self : Ref[XMLParser[Token, A]]
) -> XMLParser[Token, A] {
  fn(tokens : Seq[Token], ctx : XMLParserContext) { self.val.run(tokens, ctx) }
}

///|
pub fn pconst[Token, A](a : A) -> XMLParser[Token, A] {
  fn(tokens : Seq[Token], ctx : XMLParserContext) {
    (Some((a, tokens)), None, ctx)
  }
}
