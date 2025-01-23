///|
typealias Parser[Token, Value] = @combinator.Parser[Token, Value]

///|
typealias Seq[T] = @combinator.Seq[T]

///|
pub(all) struct XMLDocument {
  version : String
  encoding : String
  standalone : Bool
  dtd : String?
  root : XMLElement
}

///|
pub(all) struct XMLElement {
  name : String
  empty_element : Bool // 是否是单标签
  attributes : Map[String, String]
  children : Array[XMLChildren]
}

///|
pub(all) enum XMLChildren {
  Element(XMLElement)
  Reference(String)
  CDATA(String)
  PI(String)
  Comment(String)
  Text(String)
  WhiteSpace(String)
}

///|
enum XMLErrorKind {
  SyntaxError
  ValidationError
  EncodingError
  MalformedReference
  MismatchedTags(String, String) // 开始标签和结束标签
  InternalParserError
} derive(Show)

///|
struct XMLParseError {
  kind : XMLErrorKind
  message : String
  location : Location
} derive(Show)

///|
struct Location {
  mut index : Int
  mut line : Int
  mut column : Int
  length : Int
} derive(Show)

///|
impl Show for XMLDocument with output(self, logger) {
  logger.write_string("XMLDocument: " + self.to_string())
}

///|
impl Show for XMLDocument with to_string(self) {
  "<?xml version=\"\{self.version}\" encoding=\"\{self.encoding}\" standalone=\"\{self.standalone}\" ?>\n\{self.root}"
}

///|
impl Show for XMLElement with output(self, logger) {
  logger.write_string("XMLElement: " + self.to_string())
}

///|
impl Show for XMLElement with to_string(self) {
  let attributes = @string.concat(
    self.attributes.iter().map(fn(kv) { "\{kv.0}=\"\{kv.1}\"" }).collect(),
    separator=" ",
  )
  if self.empty_element {
    return "<\{self.name}" +
      (if attributes.length() == 0 { "" } else { " " }) +
      "\{attributes}/>"
  }
  let children = @string.concat(
    self.children.iter().map(fn(c) { c.to_string() }).collect(),
    separator="",
  )
  "<\{self.name} \{attributes}>\{children}</\{self.name}>"
}

///|
impl Show for XMLChildren with output(self, logger) {
  logger.write_string("XMLChildren: " + self.to_string())
}

///|
impl Show for XMLChildren with to_string(self) {
  match self {
    Element(e) => e.to_string()
    Reference(s) => "\{s}"
    CDATA(s) => "<![CDATA[\{s}]]>"
    PI(s) => "<?\{s}?>"
    Comment(s) => "<!--\{s}-->"
    Text(s) => s
    WhiteSpace(s) => s
  }
}
