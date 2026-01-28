///|
test "fail" {
  let str = "<?xml version=\"&$\" encoding=\"eXh4Qc\"\u{0f}F\u{1d}[]H\u{19}A\u{00}\" standalone=\"true\" ?>\n<vjolNG04hr key_1=\"4\u{1c}r\u{06}l\u{10}dxSa\u{10}\u{01}\" key_2=\"<)jxL\u{16}x\u{0b}R\u{15}\u{0c}w\u{1b}]w\u{00}eh\" key_3=\".cXWh$oJfX\u{16}\u{1c}Y?J\" key_4=\"$f/1\" key_5=\"4Y\" key_6=\"\u{0c}0N*$\" key_7=\"=\" key_8=\"E;#\" key_9=\"W.\u{07}t%i\u{1e}umy\u{05}'@9\"><![CDATA[]]><X ></X></vjolNG04hr>"
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
  let result = parser.run(@combinator.Seq::from_string(str)).unwrap()
  let str =
    #|<!DOCTYPE doc [
    #|<!ELEMENT doc (#PCDATA)>
    #|<!ATTLIST doc a IDREFS #IMPLIED>
    #|]>
  let result = parser.run(@combinator.Seq::from_string(str)).unwrap()

}

///|
fn is_valid(s : String) -> Bool {
  let s = s.replace(old=".xml", new="")
  let id = try? @strconv.parse_int(s)
  match id {
    Err(_) => false
    Ok(id) =>
      match id {
        49..=51 => false
        _ => true
      }
  }
}

///|
test "xmlconf valid sa" {
  let dir = "resource/xmlconf/xmltest/valid/sa"
  let files = @fs.read_dir(dir).filter(is_valid)
  let mut cnt = 0
  for file in files {
    if file.has_suffix(".xml") {
      let str = @fs.read_file_to_string(dir + "/" + file)
      let bytes = @fs.read_file_to_bytes(dir + "/" + file)
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
  inspect(cnt, content=files.length().to_string())
}

// ///|
// test "xmlconf not-wf sa" {
//   let files = @fs.read_dir!("resource/xmlconf/xmltest/not-wf/sa").filter(
//     is_valid,
//   )
//   let mut cnt = 0
//   for file in files {
//     if file.ends_with(".xml") {
//       let str = @fs.read_file_to_string!(
//         "resource/xmlconf/xmltest/not-wf/sa/" + file,
//       )
//       let bytes = @fs.read_file_to_bytes!(
//         "resource/xmlconf/xmltest/not-wf/sa/" + file,
//       )
//       let result = xml_from_string(str)
//       match result {
//         None =>
//           // println("ok " + file)
//           cnt += 1
//         Some(_) => {
//           println("fail " + file)
//           println(str)
//           // println(bytes)
//           println(result)
//           // return
//         }
//       }
//     }
//   }
//   println("passed: \{cnt}/\{files.length()}")
//   inspect(cnt, content=files.length().to_string())
// }
