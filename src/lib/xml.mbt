///|
pub(all) struct XMLDocument {
  version : String
  encoding : String
  standalone : Bool
  root : XMLElement
}

///|
pub(all) struct XMLElement {
  name : String
  attributes : Map[String, String]
  children : @queue.T[XMLChildren]
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
