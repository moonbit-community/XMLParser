///| A possibility infinite lazy list
pub type Seq[T] ArrayView[T]

///| A parser combinator
pub type Parser[Token, Value] (Seq[Token]) -> (Value, Seq[Token])?