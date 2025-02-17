# XMLParser

XML Parser is an XML parsing library written in MoonBit.
It can parse XML strings into structured data, supporting basic elements, attributes, comments, CDATA, processing instructions, etc., of XML documents.
The library is implemented using parser combinators.


# Examples

```Moonbit
let str =
#|<?xml version="1.0"?>
#|<root>
#|  Text before
#|  <child empty="true"/>
#|  Text between
#|  <?php echo "processing instruction" ?>
#|  <![CDATA[Preserving <tags> in CDATA]]>
#|  <!-- A comment here -->
#|  <child>
#|    Nested text
#|    <grandchild />
#|    More nested text
#|  </child>
#|  Text after
#|</root>
let xml = @parser.xml_from_string(str)
let xml = @parser.xml_from_iter(str.iter())
let (xml, ctx) = @parser.xml_from_string_with_ctx(str)
let xml = xml.unwrap()
println(xml)
```

