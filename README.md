# XMLParser

XML Parser is an XML parsing library written in MoonBit.
It can parse XML strings into structured data, supporting basic elements, attributes, comments, CDATA, processing instructions, etc., of XML documents.
The library is implemented using parser combinators.


# Examples

```Moonbit
let xml = @lib.xml_from_string("<?xml version=\"1.0\"?><root><child>Content</child></root>")
println(xml.root)
```

