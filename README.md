# RuifengFu/XMLParser

XML Parser 是一个用MoonBit编写的XML解析库。
它可以将XML字符串解析成结构化的数据，支持XML文档的基本元素、属性、注释、CDATA、处理指令等。
该库使用了parser combinator的方式来实现


# Example

```Moonbit
let xml = xml_from_string("<?xml version=\"1.0\"?><root><child>Content</child></root>")
println(xml)
```

