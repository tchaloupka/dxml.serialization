module dxml.serialization.attrs;

struct XmlNameAttribute { string name; }
struct XmlOptionalAttribute {}
struct XmlAttrAttribute {}
struct XmlTextAttribute {}
struct XmlSkipAttribute {}

@property XmlNameAttribute xmlName(string name) { return XmlNameAttribute(name); }
@property XmlOptionalAttribute xmlOptional() { return XmlOptionalAttribute(); }
@property XmlAttrAttribute xmlAttr() { return XmlAttrAttribute(); }
@property XmlTextAttribute xmlText() { return XmlTextAttribute(); }
@property XmlSkipAttribute xmlSkip() { return XmlSkipAttribute(); }
