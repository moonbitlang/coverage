///|
priv enum XmlAttribute {
  Attribute(String, String)
}

///|
priv enum Xml {
  Declaration
  Text(String)
  Element(String, Array[XmlAttribute], Array[Xml])
  EmptyElement(String, Array[XmlAttribute])
  Fragment(Array[Xml])
}

///|
fn is_xml_character(character : Char) -> Bool {
  let codepoint = character.to_int()
  codepoint == 0x09 ||
  codepoint == 0x0a ||
  codepoint == 0x0d ||
  (codepoint >= 0x20 && codepoint <= 0xd7ff) ||
  (codepoint >= 0xe000 && codepoint <= 0xfffd) ||
  (codepoint >= 0x10000 && codepoint <= 0x10ffff)
}

///|
fn write_xml_text(logger : &Logger, text : StringView) -> Unit {
  for character in text {
    if !is_xml_character(character) {
      logger <+ "&#xFFFD;"
    } else {
      match character {
        '\t' => logger <+ "&#x9;"
        '\n' => logger <+ "&#xA;"
        '\r' => logger <+ "&#xD;"
        '&' => logger <+ "&amp;"
        '<' => logger <+ "&lt;"
        '>' => logger <+ "&gt;"
        character => logger.write_char(character)
      }
    }
  }
}

///|
fn write_xml_attribute_value(logger : &Logger, value : StringView) -> Unit {
  for character in value {
    if !is_xml_character(character) {
      logger <+ "&#xFFFD;"
    } else {
      match character {
        '\t' => logger <+ "&#x9;"
        '\n' => logger <+ "&#xA;"
        '\r' => logger <+ "&#xD;"
        '&' => logger <+ "&amp;"
        '<' => logger <+ "&lt;"
        '>' => logger <+ "&gt;"
        '"' => logger <+ "&quot;"
        '\'' => logger <+ "&apos;"
        character => logger.write_char(character)
      }
    }
  }
}

///|
fn Xml::is_block_element(self : Xml) -> Bool {
  self is Element(_, _, _) || self is EmptyElement(_, _)
}

///|
fn XmlAttribute::output(self : XmlAttribute, logger : &Logger) -> Unit {
  let Attribute(name, value) = self
  logger <+ " "
  logger.write_string(name)
  logger <+ "=\""
  write_xml_attribute_value(logger, value)
  logger <+ "\""
}

///|
fn Xml::output_at(self : Xml, logger : &Logger, depth : Int) -> Unit {
  match self {
    Declaration => logger <+ "<?xml version=\"1.0\" ?>"
    Text(text) => write_xml_text(logger, text)
    Element(tag, attributes, children) => {
      logger <+ "<"
      logger.write_string(tag)
      attributes.each(attribute => attribute.output(logger))
      logger <+ ">"
      match children {
        [] => ()
        [Text(text)] => write_xml_text(logger, text)
        _ if children.all(child => child.is_block_element()) => {
          logger <+ "\n"
          for index, child in children {
            logger.write_string("  ".repeat(depth + 1))
            child.output_at(logger, depth + 1)
            if index + 1 < children.length() {
              logger <+ "\n"
            }
          }
          logger <+ "\n"
          logger.write_string("  ".repeat(depth))
        }
        _ => children.each(child => child.output_at(logger, depth))
      }
      logger <+ "</"
      logger.write_string(tag)
      logger <+ ">"
    }
    EmptyElement(tag, attributes) => {
      logger <+ "<"
      logger.write_string(tag)
      attributes.each(attribute => attribute.output(logger))
      logger <+ "/>"
    }
    Fragment(children) =>
      for index, child in children {
        child.output_at(logger, depth)
        if index + 1 < children.length() {
          logger <+ "\n"
        }
      }
  }
}

///|
impl Show for Xml with fn output(self, logger) {
  self.output_at(logger, 0)
}
