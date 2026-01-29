///|
test "Seq from string" {
  let sequence = Seq::from_string("沪A")
  assert_eq(sequence.length(), 2)
  assert_false(sequence.is_empty())
  inspect(sequence.uncons(), content="Some(('沪', 'A'))")
  let (_, sequence) = sequence
    .uncons()
    .unwrap_or_error(Failure::Failure("Shouldn't happen"))
  assert_false(sequence.is_empty())
  inspect(sequence.uncons(), content="Some(('A', ))")
  let (_, sequence) = sequence
    .uncons()
    .unwrap_or_error(Failure::Failure("Shouldn't happen"))
  assert_true(sequence.is_empty())
  let sequence = Seq::from_string("🀄️")
  assert_eq(sequence.length(), 2)
  inspect(sequence.uncons(), content="Some(('🀄', '\u{fe0f}'))")
}

///|
test "Seq from array" {
  let sequence = Seq::from_array("沪A".iter().collect()[:])
  assert_eq(sequence.length(), 2)
  assert_false(sequence.is_empty())
  inspect(sequence.uncons(), content="Some(('沪', 'A'))")
  let (_, sequence) = sequence
    .uncons()
    .unwrap_or_error(Failure::Failure("Shouldn't happen"))
  assert_false(sequence.is_empty())
  inspect(sequence.uncons(), content="Some(('A', ))")
  let (_, sequence) = sequence
    .uncons()
    .unwrap_or_error(Failure::Failure("Shouldn't happen"))
  assert_true(sequence.is_empty())
  let sequence = Seq::from_array("🀄️".iter().collect()[:])
  assert_eq(sequence.length(), 2)
  inspect(sequence.uncons(), content="Some(('🀄', '\u{fe0f}'))")
}
