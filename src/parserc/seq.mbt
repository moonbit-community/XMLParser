///|
pub fn Seq::new[T](view : ArrayView[T]) -> Seq[T] {
  view
}

///| Checks if the sequence is empty
pub fn Seq::is_empty[T](self : Seq[T]) -> Bool {
  self._.length() == 0
}

///|
pub fn Seq::default[T]() -> Seq[T] {
  [][:]
}

///| Unwrap a sequence
///
/// If `self` is empty, then `seq.uncons()` is `None`  
/// Else is `Some(hd, tl)` where `hd` is the head of the sequence
/// and `tl` is the tail
pub fn Seq::uncons[T](self : Seq[T]) -> (T, Seq[T])? {
  if self.is_empty() {
    None
  } else {
    let view = self._
    Some((view[0], view[1:]))
  }
}

///| Map the sequence
///
/// If the sequence is x0, x1, ... then `seq.map(f)` is f(x0), f(x1), ...
pub fn Seq::map[T1, T2](seq : Seq[T1], f : (T1) -> T2) -> Seq[T2] {
  seq._.map(f)[:]
}

///| Construct a sequence from list
pub fn Seq::from_list[T](list : @immut/list.T[T]) -> Seq[T] {
  list.to_array()[:]
}

///| Construct a sequence from string
pub fn Seq::from_string(str : String) -> Seq[Char] {
  let seq = []
  let mut offset = 0
  while offset < str.length() {
    let ch = str[offset]
    if ch.to_int() >= 0xd800 && ch.to_int() <= 0xdbff {
      let ch2 = str[offset + 1]
      seq.push(
        Char::from_int(
          0x10000 + ((ch.to_int() - 0xd800) << 10) + ch2.to_int() - 0xdc00,
        ),
      )
      offset += 2
    } else {
      seq.push(ch)
      offset += 1
    }
  }
  seq[:]
}

///| Construct a sequence from array
pub fn Seq::from_array[T](array : ArrayView[T]) -> Seq[T] {
  array
}

///|
pub fn length[T](self : Seq[T]) -> Int {
  self._.length()
}

///| Look forward `n` characters
pub fn Seq::peek_char(self : Seq[Char], n : Int) -> String? {
  if self.length() >= n {
    Some(self._[:n].fold(init="", fn(s, c) { s + c.to_string() }))
  } else {
    None
  }
}

///|
pub impl[T : Show] Show for Seq[T] with to_string(self) {
  self._.map(Show::to_string).join("")
}

///|
pub impl[T : Show] Show for Seq[T] with output(self, log) {
  self._.each(fn(t) { t.output(log) })
  return
}
