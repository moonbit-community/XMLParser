// 这个文件中实现一些易用的api

// 查找元素

///|
pub(open) trait XMLVisitor {
  visit(Self, XMLElement) -> Unit
}

///|
pub(open) trait XMLNode {
  accept(Self, &XMLVisitor) -> Unit
}

///|
impl XMLNode for XMLElement with accept(self, visitor) {
  visitor.visit(self)
  for child in self.children {
    if child is Element(element) {
      element.accept(visitor)
    }
  }
}

///|
pub(all) struct GetElementVisitor {
  name : String
  elements : Array[XMLElement]
}

///|
impl XMLVisitor for GetElementVisitor with visit(self, element) {
  if element.name == self.name {
    self.elements.push(element)
  }
}

///|
pub fn get_element_by_name(
  self : XMLDocument,
  name : String,
) -> Array[XMLElement] {
  let visitor = GetElementVisitor::{ name, elements: [] }
  self.root.accept(visitor)
  visitor.elements
}

// 获取属性

///|
pub fn get_attribute(self : XMLElement, attr : String) -> String? {
  self.attributes.get(attr)
}

// 获取文本

///|
pub fn get_text(self : XMLElement) -> String {
  self.children.fold(init="", fn(str, child) {
    match child {
      Text(text) => str + text
      _ => str
    }
  })
}

// 遍历子元素

///|
pub fn get_children(self : XMLElement) -> Array[XMLChildren] {
  self.children
}
