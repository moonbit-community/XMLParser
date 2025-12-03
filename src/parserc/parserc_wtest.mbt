///|
test "sequence" {
  let parser = sequence([pchar('a'), pchar('b'), pchar('c')])
  inspect(
    parser.run(Seq::from_string("abc")),
    content="Some((['a', 'b', 'c'], ))",
  )
  inspect(parser.run(Seq::from_string("ab")), content="None")
}

///|
test "repeat" {
  let parser = pvalue(x => match x {
    '0' => Some(0)
    '1' => Some(1)
    _ => None
  })
  let repeat_n = parser.repeat_n(3)
  inspect(
    repeat_n.run(Seq::from_string("0110")),
    content="Some(([0, 1, 1], '0'))",
  )
  let repeat_0_to_n = parser.repeat_0_to_n(3)
  inspect(
    repeat_0_to_n.run(Seq::from_string("0110")),
    content="Some(([0, 1, 1], '0'))",
  )
  inspect(
    repeat_0_to_n.run(Seq::from_string("01210")),
    content="Some(([0, 1], '2''1''0'))",
  )
  inspect(repeat_0_to_n.run(Seq::from_string("2")), content="Some(([], '2'))")
  let repeat = parser.repeat()
  inspect(
    repeat.run(Seq::from_string("0110")),
    content="Some(([0, 1, 1, 0], ))",
  )
}

///|
test "pstring" {
  let parser = pstring("asdf")
  inspect(
    parser.run(Seq::from_string("asdfjkl;")),
    content=(
      #|Some(("asdf", 'j''k''l'';'))
    ),
  )
  inspect(parser.run(Seq::from_string("jkl;")), content="None")
}

///|
test "pint" {
  inspect(pint.run(Seq::from_string("12345")), content="Some((12345, ))")
  inspect(pint.run(Seq::from_string("-0")), content="Some((0, ))")
  inspect(pint.run(Seq::from_string("0")), content="Some((0, ))")
  inspect(pint.run(Seq::from_string("-01")), content="Some((0, '1'))")
  inspect(pint.run(Seq::from_string("-100")), content="Some((-100, ))")
}
