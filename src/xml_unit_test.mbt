///|
test "fail" {
  let str = "<?xml version=\"&$\" encoding=\"eXh4Qc\"\x0fF\x1d[]H\x19A\x00\" standalone=\"true\" ?>\n<vjolNG04hr key_1=\"4\x1cr\x06l\x10dxSa\x10\x01\" key_2=\"<)jxL\x16x\x0bR\x15\x0cw\x1b]w\x00eh\" key_3=\".cXWh$oJfX\x16\x1cY?J\" key_4=\"$f/1\" key_5=\"4Y\" key_6=\"\x0c0N*$\" key_7=\"=\" key_8=\"E;#\" key_9=\"W.\x07t%i\x1eumy\x05'@9\"><![CDATA[]]><X ></X></vjolNG04hr>"
  let option = xml_from_string(str)
  println(option)
}
