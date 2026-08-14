///|
priv enum HtmlAttribute {
  Attribute(String, String)
  BooleanAttribute(String)
}

///|
priv enum Html {
  Doctype
  Text(String)
  Element(String, Array[HtmlAttribute], Array[Html])
  VoidElement(String, Array[HtmlAttribute])
  Fragment(Array[Html])
}

///|
fn html_document_attributes(theme : Theme) -> Array[HtmlAttribute] {
  match theme {
    Auto => [Attribute("lang", "en")]
    Light => [Attribute("lang", "en"), Attribute("data-theme", "light")]
    Dark => [Attribute("lang", "en"), Attribute("data-theme", "dark")]
  }
}

///|
fn write_html_escaped(logger : &Logger, text : StringView) -> Unit {
  for character in text {
    match character {
      '<' => logger <+ "&lt;"
      '>' => logger <+ "&gt;"
      '&' => logger <+ "&amp;"
      '"' => logger <+ "&quot;"
      '\'' => logger <+ "&#39;"
      character => logger.write_char(character)
    }
  }
}

///|
fn HtmlAttribute::output(self : HtmlAttribute, logger : &Logger) -> Unit {
  match self {
    Attribute(name, value) => {
      logger <+ " "
      logger.write_string(name)
      logger <+ "=\""
      write_html_escaped(logger, value)
      logger <+ "\""
    }
    BooleanAttribute(name) => {
      logger <+ " "
      logger.write_string(name)
    }
  }
}

///|
impl Show for Html with fn output(self, logger) {
  match self {
    Doctype => logger <+ "<!doctype html>"
    Text(text) => write_html_escaped(logger, text)
    Element(tag, attributes, children) => {
      logger <+ "<"
      logger.write_string(tag)
      attributes.each(attribute => attribute.output(logger))
      logger <+ ">"
      for child in children {
        Show::output(child, logger)
      }
      logger <+ "</"
      logger.write_string(tag)
      logger <+ ">"
    }
    VoidElement(tag, attributes) => {
      logger <+ "<"
      logger.write_string(tag)
      attributes.each(attribute => attribute.output(logger))
      logger <+ ">"
    }
    Fragment(children) => children.each(child => Show::output(child, logger))
  }
}
