///|
test "fail" {
  let str = "<?xml version=\"&$\" encoding=\"eXh4Qc\"\x0fF\x1d[]H\x19A\x00\" standalone=\"true\" ?>\n<vjolNG04hr key_1=\"4\x1cr\x06l\x10dxSa\x10\x01\" key_2=\"<)jxL\x16x\x0bR\x15\x0cw\x1b]w\x00eh\" key_3=\".cXWh$oJfX\x16\x1cY?J\" key_4=\"$f/1\" key_5=\"4Y\" key_6=\"\x0c0N*$\" key_7=\"=\" key_8=\"E;#\" key_9=\"W.\x07t%i\x1eumy\x05'@9\"><![CDATA[]]><X ></X></vjolNG04hr>"
  let option = xml_from_string(str)
  // println(option)
}

///|
test "dtd testcase 1" {
  let str =
    #|<!DOCTYPE doc [
    #|<!ENTITY % e PUBLIC 'whatever' "e.dtd">
    #|<!ATTLIST doc a1 NMTOKENS #IMPLIED>
    #|<!ELEMENT doc (#PCDATA)>
    #|]>
  let parser = pdtd()
  let result = parser.parse(@combinator.Seq::from_string(str)).unwrap()
  let str =
    #|<!DOCTYPE doc [
    #|<!ELEMENT doc (#PCDATA)>
    #|<!ATTLIST doc a IDREFS #IMPLIED>
    #|]>
  let result = parser.parse(@combinator.Seq::from_string(str)).unwrap()

}

///|
test "xmlconf valid sa" {
  fn is_valid(s : String) {
    let s = s.replace(old=".xml", new="")
    let id = @strconv.parse_int?(s)
    match id {
      Err(_) => false
      Ok(id) =>
        match id {
          49..=51 => false
          _ => true
        }
    }
  }

  let files = @fs.read_dir!("resource/xmlconf/xmltest/valid/sa").filter(
    is_valid,
  )
  let mut cnt = 0
  for file in files {
    if file.ends_with(".xml") {
      let str = @fs.read_file_to_string!(
        "resource/xmlconf/xmltest/valid/sa/" + file,
      )
      let bytes = @fs.read_file_to_bytes!(
        "resource/xmlconf/xmltest/valid/sa/" + file,
      )
      let result = xml_from_string(str)
      match result {
        Some(_) =>
          // println("ok " + file)
          cnt += 1
        None => {
          println("fail " + file)
          println(str)
          println(bytes)
          println(result)
          return
        }
      }
    }
  }
  println("passed: \{cnt}/\{files.length()}")
  inspect!(cnt, content=files.length().to_string())
}
