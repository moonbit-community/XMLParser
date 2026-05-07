///|
test "sequence" {
  let parser = sequence([pchar('a'), pchar('b'), pchar('c')])
  debug_inspect(
    parser.run(Seq::from_string("abc")),
    content=(
      #|Some((['a', 'b', 'c']))
    ),
  )
  debug_inspect(parser.run(Seq::from_string("ab")), content="None")
}

///|
test "repeat" {
  let parser = pvalue(x => {
    match x {
      '0' => Some(0)
      '1' => Some(1)
      _ => None
    }
  })
  let repeat_n = parser.repeat_n(3)
  debug_inspect(
    repeat_n.run(Seq::from_string("0110")),
    content=(
      #|Some(([0, 1, 1], 0))
    ),
  )
  let repeat_0_to_n = parser.repeat_0_to_n(3)
  debug_inspect(
    repeat_0_to_n.run(Seq::from_string("0110")),
    content=(
      #|Some(([0, 1, 1], 0))
    ),
  )
  debug_inspect(
    repeat_0_to_n.run(Seq::from_string("01210")),
    content=(
      #|Some(([0, 1], 210))
    ),
  )
  debug_inspect(
    repeat_0_to_n.run(Seq::from_string("2")),
    content=(
      #|Some(([], 2))
    ),
  )
  let repeat = parser.repeat()
  debug_inspect(
    repeat.run(Seq::from_string("0110")),
    content=(
      #|Some(([0, 1, 1, 0]))
    ),
  )
}

///|
test "pstring" {
  let parser = pstring("asdf")
  debug_inspect(
    parser.run(Seq::from_string("asdfjkl;")),
    content=(
      #|Some(("asdf", jkl;))
    ),
  )
  debug_inspect(parser.run(Seq::from_string("jkl;")), content="None")
}

///|
test "pint" {
  debug_inspect(
    pint.run(Seq::from_string("12345")),
    content=(
      #|Some((12345))
    ),
  )
  debug_inspect(
    pint.run(Seq::from_string("-0")),
    content=(
      #|Some((0))
    ),
  )
  debug_inspect(
    pint.run(Seq::from_string("0")),
    content=(
      #|Some((0))
    ),
  )
  debug_inspect(
    pint.run(Seq::from_string("-01")),
    content=(
      #|Some((0, 1))
    ),
  )
  debug_inspect(
    pint.run(Seq::from_string("-100")),
    content=(
      #|Some((-100))
    ),
  )
}
