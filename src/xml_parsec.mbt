
struct XMLParser[Token, Value] {
  parser : (Seq[Token]) -> (Value, Seq[Token])?
  ctx : XMLParserContext
}

pub fn XMLParser::new[Char, Value](
  f : (Seq[Char]) -> (Value, Seq[Char])?,
  seq : Seq[Char]
) -> XMLParser[Char, Value] {
  let array = seq.to_array()
  {
    parser: f, 
    ctx: {
        input: array,
        index: 0,
        line_number: 0,
        column_number: 0,
        errors: [],
        warnings: [],
      }
  }
}

