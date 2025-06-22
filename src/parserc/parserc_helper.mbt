///| Parses a token with predicate
///
/// The predicate should return `Some(value)` if the tokens fulfills
/// or `None` otherwise
pub fn[Token, Value] pvalue(
  predicate : (Token) -> Value?
) -> Parser[Token, Value] {
  Parser(fn(seq) {
    let (hd, rest) = match seq.uncons() {
      Some(s) => s
      None => return None
    }
    let value = match predicate(hd) {
      Some(s) => s
      None => return None
    }
    Some((value, rest))
  })
}

///| Parser that always fail
pub fn[Token, A] pfail() -> Parser[Token, A] {
  Parser(fn(_tokens) { None })
}

///| Parser that always succeed with given value
pub fn[Token, A] pconst(a : A) -> Parser[Token, A] {
  Parser(fn(tokens) { Some((a, tokens)) })
}

// String specific parsers

///|
pub fn pchar_such_that(predicate : (Char) -> Bool) -> Parser[Char, Char] {
  pvalue(char => @option.when(predicate(char), () => char))
}

///|
pub fn pchar(char : Char) -> Parser[Char, Char] {
  pchar_such_that(fn(c) { c == char })
}

///| parser for integer
///
/// [ "-" ] ( %x30 / (%x31-39) *(%x30-39)
pub let pint : Parser[Char, Int] = pdigits.map(fn(tuple) {
  let sign = tuple.0
  let digits = tuple.1
  let i = digits.1.fold(fn(a, b) { 10 * a + b }, init=digits.0)
  match sign {
    Some(_) => -i
    None => i
  }
})

///| parser for integer 64 bits
///
/// [ "-" ] ( %x30 / (%x31-39) *(%x30-39)
pub let pint64 : Parser[Char, Int64] = pdigits.map(fn(tuple) {
  let sign = tuple.0
  let digits = tuple.1
  let i = digits.1.fold(
    fn(a, b) { 10L * a + b.to_int64() },
    init=digits.0.to_int64(),
  )
  match sign {
    Some(_) => -i
    None => i
  }
})

///| parser that tries to match the given string
pub fn pstring(string : String) -> Parser[Char, String] {
  Parser(fn(seq) {
    let iter = loop (seq, Seq::from_string(string)) {
      (iter, input) => {
        if not(input.is_empty()) {
          let (target, rest_target) = match input.uncons() {
            None => return None
            Some(s) => s
          }
          let (char, rest) = match iter.uncons() {
            None => return None
            Some(s) => s
          }
          if target != char {
            return None
          }
          continue (rest, rest_target)
        }
        break iter
      }
    }
    Some((string, iter))
  })
}

///| parse digit
///
/// %x30-39
pub let pdigit : Parser[Char, Int] = one_of([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])

///|
let pdigits : Parser[Char, (Char?, (Int, Array[Int]))] = pchar('-')
  .optional()
  .and_then(
    pchar('0')
    .map(fn(_ch) { (0, []) })
    .or_else(
      pvalue(x => match x {
        '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' as char =>
          Some(char.to_int() - 0x30)
        _ => None
      }).and_then(pdigit.repeat()),
    ),
  )
