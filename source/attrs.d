module xmlser.attrs;

struct NameAttribute { string name; }
struct OptionalAttribute {}
struct AttrAttribute {}

@property NameAttribute name(string name) { return NameAttribute(name); }
@property OptionalAttribute optional() { return OptionalAttribute(); }
@property AttrAttribute attr() { return AttrAttribute(); }
