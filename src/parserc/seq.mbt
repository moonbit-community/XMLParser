///|
pub fn[T] Seq::new(view : ArrayView[T]) -> Seq[T] {
  view
}

///| Checks if the sequence is empty
pub fn[T] Seq::is_empty(self : Seq[T]) -> Bool {
  self.inner().length() == 0
}

///|
pub fn[T] Seq::default() -> Seq[T] {
  [][:]
}

///| Unwrap a sequence
///
/// If `self` is empty, then `seq.uncons()` is `None`  
/// Else is `Some(hd, tl)` where `hd` is the head of the sequence
/// and `tl` is the tail
pub fn[T] Seq::uncons(self : Seq[T]) -> (T, Seq[T])? {
  if self.is_empty() {
    None
  } else {
    let view = self.inner()
    Some((view[0], view[1:]))
  }
}

///| Map the sequence
///
/// If the sequence is x0, x1, ... then `seq.map(f)` is f(x0), f(x1), ...
pub fn[T1, T2] Seq::map(seq : Seq[T1], f : (T1) -> T2) -> Seq[T2] {
  seq.inner().map(f)[:]
}

///| Construct a sequence from list
pub fn[T] Seq::from_list(list : @list.List[T]) -> Seq[T] {
  list.to_array()[:]
}

///| Construct a sequence from string
pub fn Seq::from_string(str : String) -> Seq[Char] {
  let str = str.to_array()
  let seq = []
  let mut offset = 0
  while offset < str.length() {
    let ch = str[offset]
    if ch.to_int() >= 0xd800 && ch.to_int() <= 0xdbff {
      let ch2 = str[offset + 1]
      seq.push(
        Int::unsafe_to_char(
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
pub fn[T] Seq::from_array(array : ArrayView[T]) -> Seq[T] {
  array
}

///|
pub fn[T] length(self : Seq[T]) -> Int {
  self.inner().length()
}

///| Look forward `n` characters
pub fn Seq::peek_char(self : Seq[Char], n : Int) -> String? {
  if self.length() >= n {
    Some(self.inner()[:n].fold(init="", fn(s, c) { s + c.to_string() }))
  } else {
    None
  }
}

///|
pub fn[T] Seq::to_array(self : Seq[T]) -> Array[T] {
  self.inner().iter().to_array()
}

///|
pub fn[T] Seq::to_iter(self : Seq[T]) -> Iter[T] {
  self.inner().iter()
}

///|
pub impl[T : Show] Show for Seq[T] with to_string(self) {
  self.inner().map(Show::to_string).join("")
}

///|
pub impl[T : Show] Show for Seq[T] with output(self, log) {
  self.inner().each(fn(t) { t.output(log) })
  return
}
