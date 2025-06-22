///|
typealias @combinator.Parser

///|
typealias @combinator.Seq

///|
pub(all) struct XMLDocument {
  version : String
  encoding : String
  standalone : Bool
  dtd : DocTypeDecl?
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
pub(all) struct DocTypeDecl {
  name : String
  externalID : ExternalID?
  intSubset : Array[DTDStatement]?
}

///|
pub impl Show for DocTypeDecl with output(self, logger) {
  let external_id_str = match self.externalID {
    None => ""
    Some(id) => " " + id.to_string()
  }
  let subset_str = match self.intSubset {
    None => ""
    Some(arr) =>
      " [" + arr.map(fn(statement) { statement.to_string() }).join("") + "]"
  }
  logger.write_string("<!DOCTYPE \{self.name}\{external_id_str}\{subset_str}>")
}

///|
pub(all) enum DTDStatement {
  Decl(MarkUpDecl)
  Sep(String)
}

///|
pub impl Show for DTDStatement with output(self, logger) {
  match self {
    Decl(decl) => logger.write_string(decl.to_string())
    Sep(s) => logger.write_string(s)
  }
}

///|
pub(all) enum MarkUpDecl {
  ElementDecl(ElementDecl)
  AttListDecl(AttlistDecl)
  EntityDecl(EntityDecl)
  NotationDecl(NotationDecl)
  PI(String)
  Comment(String)
}

///|
pub impl Show for MarkUpDecl with output(self, logger) {
  match self {
    ElementDecl(e) => logger.write_string(e.to_string())
    AttListDecl(a) => logger.write_string(a.to_string())
    EntityDecl(e) => logger.write_string(e.to_string())
    NotationDecl(n) => logger.write_string(n.to_string())
    PI(s) => logger.write_string("<?\{s}?>")
    Comment(s) => logger.write_string("<!--\{s}-->")
  }
}

///|
pub(all) struct ElementDecl {
  name : String
  content_spec : ContentSpec
}

///|
pub impl Show for ElementDecl with output(self, logger) {
  logger.write_string("<!ELEMENT \{self.name} \{self.content_spec}>")
}

///|
pub(all) enum ContentSpec {
  EMPTY
  ANY
  Mixed(Array[String])
  Children(ChildrenContentSpec)
}

///|
pub impl Show for ContentSpec with output(self, logger) {
  match self {
    EMPTY => logger.write_string("EMPTY")
    ANY => logger.write_string("ANY")
    Mixed(arr) => {
      let str = arr.join("|")
      if arr.length() > 0 {
        logger.write_string("(#PCDATA|\{str})*")
      } else {
        logger.write_string("(#PCDATA)")
      }
    }
    Children(c) => logger.write_string(c.to_string())
  }
}

///|
pub typealias ContentParticle as ChildrenContentSpec

///|
pub(all) type ContentParticle (SingleContentParticle, ChildrenContentSpecOp?)

///|
pub impl Show for ContentParticle with output(self, logger) {
  match self.inner() {
    (p, None) => logger.write_string(p.to_string())
    (p, Some(op)) => logger.write_string("\{p}\{op}")
  }
}

///|
pub(all) enum ChildrenContentSpecOp {
  Optional
  ZeroOrMore
  OneOrMore
}

///|
pub impl Show for ChildrenContentSpecOp with output(self, logger) {
  match self {
    Optional => logger.write_string("?")
    ZeroOrMore => logger.write_string("*")
    OneOrMore => logger.write_string("+")
  }
}

///|
pub(all) enum SingleContentParticle {
  Name(String)
  Seq(Array[ContentParticle])
  Choice(Array[ContentParticle])
}

///|
pub impl Show for SingleContentParticle with output(self, logger) {
  match self {
    Name(s) => logger.write_string(s)
    Seq(arr) => {
      let str = arr.map(fn(p) { p.to_string() }).join(", ")
      logger.write_string("(\{str})")
    }
    Choice(arr) => {
      let str = arr.map(fn(p) { p.to_string() }).join(" | ")
      logger.write_string("(\{str})")
    }
  }
}

///|
pub(all) struct AttlistDecl {
  name : String
  att_defs : Array[AttDef]
}

///|
pub impl Show for AttlistDecl with output(self, logger) {
  let att_str = self.att_defs.map(fn(att) { att.to_string() }).join("")
  logger.write_string("<!ATTLIST \{self.name}\{att_str}>")
}

///|
pub(all) struct AttDef {
  name : String
  att_type : AttType
  default_decl : DefaultDecl
}

///|
pub impl Show for AttDef with output(self, logger) {
  logger.write_string(" \{self.name} \{self.att_type} \{self.default_decl}")
}

///|
pub(all) enum DefaultDecl {
  Required
  Implied
  Fixed(String)
  Value(String)
}

///|
pub impl Show for DefaultDecl with output(self, logger) {
  match self {
    Required => logger.write_string("#REQUIRED")
    Implied => logger.write_string("#IMPLIED")
    Fixed(s) => logger.write_string("#FIXED \{s}")
    Value(s) => logger.write_string(s)
  }
}

///|
pub(all) enum AttType {
  StringType(String)
  TokenizedType(String)
  NotationType(Array[String])
  Enumeration(Array[String])
}

///|
pub impl Show for AttType with output(self, logger) {
  match self {
    StringType(_) => logger.write_string("CDATA")
    TokenizedType(s) => logger.write_string(s)
    NotationType(s) => {
      let str = s.join(" | ")
      logger.write_string("NOTATION (\{str})")
    }
    Enumeration(s) => {
      let str = s.join(" | ")
      logger.write_string("(\{str})")
    }
  }
}

///|
pub(all) enum EntityDecl {
  GEDecl(String, EntityDef) // General Entity Declaration
  PEDecl(String, EntityDef) // Parameter Entity Declaration
}

///|
pub(all) enum EntityDef {
  EntityValue(String)
  GExternalID(ExternalID, String?)
  PExternalID(ExternalID)
}

///|
pub(all) enum ExternalID {
  System(String)
  Public(String, String)
}

///|
pub(all) struct NotationDecl {
  name : String
  id : NotationDeclID
}

///|
pub(all) enum NotationDeclID {
  PublicID(String)
  ExternalID(ExternalID)
}

///|
pub(all) enum Misc {
  Comment(String)
  PI(String)
  WhiteSpace(String)
}

///|
pub(all) enum XMLErrorKind {
  SyntaxError
  ValidationError
  EncodingError
  MalformedReference
  MismatchedTags(String, String) // 开始标签和结束标签
  InternalParserError
} derive(Show)

///|
pub(all) struct XMLParseError {
  kind : XMLErrorKind
  message : String
  location : Location
} derive(Show)

///|
pub(all) struct Location {
  mut index : Int
  mut line : Int
  mut column : Int
  length : Int
} derive(Show)

///|
pub impl Show for XMLDocument with output(self, logger) {
  logger.write_string("XMLDocument: " + self.to_string())
}

///|
pub impl Show for XMLDocument with to_string(self) {
  let dtd_str = match self.dtd {
    Some(dtd) => dtd.to_string()
    None => ""
  }
  "<?xml version=\"\{self.version}\" encoding=\"\{self.encoding}\" standalone=\"\{self.standalone}\" ?>\{dtd_str}\n\{self.root}"
}

///|
pub impl Show for XMLElement with output(self, logger) {
  logger.write_string("XMLElement: " + self.to_string())
}

///|
pub impl Show for XMLElement with to_string(self) {
  let attributes = self.attributes
    .iter()
    .map(kv => "\{kv.0}=\"\{kv.1}\"")
    .join(" ")
  if self.empty_element {
    return "<\{self.name}" +
      (if attributes.length() == 0 { "" } else { " " }) +
      "\{attributes}/>"
  }
  let children = self.children.map(c => c.to_string()).join("")
  "<\{self.name} \{attributes}>\{children}</\{self.name}>"
}

///|
pub impl Show for XMLChildren with output(self, logger) {
  logger.write_string("XMLChildren: " + self.to_string())
}

///|
pub impl Show for XMLChildren with to_string(self) {
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

///|
pub impl Show for EntityDecl with output(self, logger) {
  match self {
    GEDecl(name, def) => logger.write_string("<!ENTITY \{name} \{def}>")
    PEDecl(name, def) => logger.write_string("<!ENTITY % \{name} \{def}>")
  }
}

///|
pub impl Show for EntityDef with output(self, logger) {
  match self {
    EntityValue(value) => logger.write_string(value)
    PExternalID(id) => logger.write_string(id.to_string())
    GExternalID(id, None) => logger.write_string(id.to_string())
    GExternalID(id, Some(n)) =>
      logger.write_string(id.to_string() + " NDATA \{n}")
  }
}

///|
pub impl Show for ExternalID with output(self, logger) {
  match self {
    System(s) => logger.write_string("SYSTEM \{s}")
    Public(p, s) => logger.write_string("PUBLIC \{p} \{s}")
  }
}

///|
pub impl Show for NotationDeclID with output(self, logger) {
  match self {
    PublicID(s) => logger.write_string("PUBLIC \{s}")
    ExternalID(id) => logger.write_string(id.to_string())
  }
}

///|
pub impl Show for NotationDecl with output(self, logger) {
  logger.write_string("<!NOTATION \{self.name} \{self.id}>")
}

///|
pub fn XMLParseError::is_fatal(self : XMLParseError) -> Bool {
  match self.kind {
    SyntaxError => true
    ValidationError => true
    EncodingError => true
    MalformedReference => true
    MismatchedTags(_, _) => true
    InternalParserError => true
  }
}
