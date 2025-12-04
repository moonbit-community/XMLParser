///|
/// A possibility infinite lazy list
pub struct Seq[T](ArrayView[T])

///|
/// A parser combinator
pub struct Parser[Token, Value]((Seq[Token]) -> (Value, Seq[Token])?)
