module dxml.serialization.deserializer;

import dxml.parser;
import dxml.serialization.attrs;
import std.conv : to;
import std.datetime.date : Date, DateTime, TimeOfDay;
import std.datetime.systime : SysTime;
import std.exception : enforce;
import std.experimental.logger;
import std.format : format;
import std.meta;
import std.range : ElementType, isForwardRange;
import std.traits;
import std.typecons : Nullable;

version(unittest)
{
    version (Have_unit_threaded) import unit_threaded;
}

T deserialize(T, R)(R input) if (isForwardRange!R && isSomeChar!(ElementType!R))
{
	auto r = parseXML!simpleXML(input);

	enforce!XMLDeserializationException(!r.empty, "Xml range is already empty. Cannot deserialize " ~ T.stringof);

	assert(r.front.type == EntityType.elementStart);

	Context ctx;
	ctx.path = r.front.name;
	return deserialize!T(r, ctx);
}

private:

T deserialize(T, R)(ref R range, ref Context ctx) if (is(R : EntityRange!(C), C...))
{
	enforce!XMLDeserializationException(
		!range.empty,
		format!"Xml range is already empty. Cannot deserialize %s in %s"(T.stringof, ctx.path)
	);

	enforce!XMLDeserializationException(range.front.type == EntityType.elementStart, "ElementStart is expected");

	logf("Reading %s", ctx.path);

	return deserializeImpl!T(range, ctx);
}

T deserializeImpl(T, R)(ref R range, ref Context ctx)
if (
	is(R : EntityRange!(C), C...)
	&& (
		(
			is(T == struct)
			&& !is(T : Nullable!U, U)
			&& !is(T == Date) && !is(T == DateTime) && !is(T == TimeOfDay) && !is(T == SysTime))
		|| is(T == class))
	)
{
	static if (is(T == struct)) T res = T.init;
	else static if (isAbstractClass!T)
	{
		//TODO
		T res;
	}
	else T res = new T();

	// read attributes
	alias attrFields = getSymbolsByUDA!(T, XmlAttrAttribute);
	static if (attrFields.length)
	{
		/// XML attributes may not be ordered so we need to read them in apearance order

		static foreach (i; 0..attrFields.length)
		{
			// generate flags indicating attr was set
			static if (!hasOptional!(attrFields[i]))
			{
				mixin("bool has"~attrFields[i].stringof~";");
			}
		}

		foreach (attr; range.front.attributes)
		{
			Lsw: switch (attr.name)
			{
				static foreach(i; 0..attrFields.length)
				{
					case getSymbolName!(attrFields[i]):
						alias VT = typeof(__traits(getMember, res, attrFields[i].stringof));
						static if (is(VT : Nullable!U, U)) __traits(getMember, res, attrFields[i].stringof) = VT(attr.value.parse!(TemplateArgsOf!VT[0]));
						else
						{
							__traits(getMember, res, attrFields[i].stringof) = attr.value.parse!VT;
						}

						static if (!hasOptional!(attrFields[i])) mixin("has"~attrFields[i].stringof) = true;
						break Lsw;
				}
				default:
					logf("Skipping attribute: %s.%s", range.front.name, attr.name);
					break;
			}
		}

		/// Check non optional args was set
		static foreach (i; 0..attrFields.length)
		{
			static if (!hasOptional!(attrFields[i]))
			{
				enforce!XMLDeserializationException(
					mixin("has"~attrFields[i].stringof),
					format!"Missing nonoptional attribute %s.%s"(ctx.path, getSymbolName!(attrFields[i]))
				);
			}
		}
	}

	range.popFront(); //move to members

	// read members
	foreach (member; __traits(derivedMembers, T))
	{
		static if (!hasUDA!(__traits(getMember, T, member), XmlAttrAttribute)) //skip already handled attribute members
		{
			enum isMemberVariable = is(typeof(() {
				__traits(getMember, res, member) = __traits(getMember, res, member).init;
			}));
			static if (isMemberVariable)
			{
				alias mtype = typeof(__traits(getMember, T, member));
				alias sym = Alias!(__traits(getMember, res, member));
				enum mname = getSymbolName!sym;

				enum opt = hasOptional!sym;
				enforce!XMLDeserializationException(!range.empty || opt, "Xml range is already empty. Cannot deserialize " ~ T.stringof);

				// handle text values
				static if (isTextValue!sym)
				{
					if (range.front.type == EntityType.text)
					{
						__traits(getMember, res, member) = range.front.text.parse!mtype;
						range.popFront();
					}
					else
					{
						enforce!XMLDeserializationException(
							range.front.type == EntityType.elementEnd,
							format!"Unexpected EntityType: %s"(range.front.type)
						);
					}
				}
				else
				{
					if (range.front.type == EntityType.elementStart)
					{
						import std.algorithm : canFind;
						if (range.front.name.canFind(":")) // FIXME: Add support for namespaces
						{
							logf("Skipping unknown element: %s", range.front.name);
							range = range.skipContents();
							range.popFront();
						}
						else if (isMemberName(range.front.name, mname))
						{
							static if (hasSkip!sym)
							{
								logf("Skipping: %s.%s", ctx.path, range.front.name);
								range = range.skipContents();
								range.popFront();
							}
							else
							{
								enforce!XMLDeserializationException(range.front.type == EntityType.elementStart, "Element start expected");
								immutable lpath = ctx.path.length;
								ctx.level++;
								ctx.path ~= "."; ctx.path ~= range.front.name;
								scope (exit)
								{
									ctx.level--;
									ctx.path.length = lpath;
								}
								__traits(getMember, res, member) = deserialize!mtype(range, ctx);
							}
						}
						else
						{
							// unexpected element, try next if this one is optional
							enforce!XMLDeserializationException(
								opt,
								format!"Unexpected element: %s.%s, expected: %s.%s"(ctx.path, range.front.name, ctx.path, mname)
							);
						}
					}
					else if (range.front.type == EntityType.elementEnd)
					{
						enforce!XMLDeserializationException(opt, format!"Missing non optional element %s.%s"(ctx.path, mname));
					}
					else enforce!XMLDeserializationException(false, format!"Unexpected EntityType: %s for %s"(range.front.type, mname));
				}
			}
		}
	}

	enforce!XMLDeserializationException(!range.empty, "Xml range is already empty. Cannot deserialize " ~ T.stringof);

	if (!range.empty)
	{
		enforce!XMLDeserializationException(
			range.front.type == EntityType.elementEnd,
			format!"Unexpected elements at the end of %s: %s"(ctx.path, range.front.type)
		);
		range.popFront();
	}

	return res;
}

/// Wrapper to read Nullable values
T deserializeImpl(T, R)(ref R range, ref Context ctx) if (is(T : Nullable!U, U))
{
	return T(deserializeImpl!(TemplateArgsOf!T[0])(range, ctx));
}

/// Basic types deserialization
T deserializeImpl(T, R)(ref R range, ref Context ctx)
if (
	is(T == enum) || isNumeric!T || is(T == bool)
	|| is(T == Date) || is(T == DateTime) || is(T == TimeOfDay) || is(T == SysTime)
)
{
	range.popFront();
	T res = range.front.text.parse!T;
	range.popFront();
	range.popFront();
	return res;
}

/// String type deserialization
T deserializeImpl(T, R)(ref R range, ref Context ctx) if (is(T == string))
{
	range.popFront();
	T res;
	if (range.front.type == EntityType.text)
	{
		res = range.front.text;
		range.popFront();
	}
	range.popFront();
	return res;
}

/// Array deserialization
T deserializeImpl(T, R)(ref R range, ref Context ctx) if (isArray!T && !is(T == string))
{
	import std.array : Appender;

	string elemName = range.front.name;

	auto app = Appender!T();

	size_t idx;
	while (range.front.type == EntityType.elementStart)
	{
		if (range.front.name != elemName) break; // done reading array elements
		immutable lpath = ctx.path.length;
		ctx.level++;
		ctx.path ~= "."; ctx.path ~= range.front.name;
		ctx.path ~= "[";
		ctx.path ~= idx.to!string; // TODO: formatted write
		ctx.path ~= "]";
		scope (exit)
		{
			ctx.level--;
			ctx.path.length = lpath;
		}
		app ~= deserialize!(ElementType!T)(range, ctx);
		idx++;
	}
	return app.data;
}

class XMLDeserializationException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

static string getSymbolName(alias S)()
{
	static if (hasUDA!(S, XmlNameAttribute)) return getUDAs!(S, XmlNameAttribute)[0].name;
	else return S.stringof;
}

static bool isMemberName(string entityName, string memberName)
{
	import std.algorithm : equal;
	import std.range : chain;
	import std.uni : toUpper;

	if (entityName == memberName) return true;
	if (equal(entityName, chain(memberName[0..1].toUpper, memberName[1..$]))) return true;
	return false;
}

/++
	Context of the deserialization.
	This is used to pass the informations about current context between the deserialization methods.
+/
struct Context
{
	int level;
	string path;
	//TODO: namespaces
}

alias hasOptional(alias S) = hasUDA!(S, XmlOptionalAttribute);
alias hasSkip(alias S) = hasUDA!(S, XmlSkipAttribute);
alias isTextValue(alias S) = hasUDA!(S, XmlTextAttribute);


// Helper for string conversions with special type values handling
T parse(T)(string value)
{
	static if (is(T == bool))
	{
		if (value == "0") return false;
		if (value == "1") return true;
		return value.to!bool;
	}
	//TimeZone is dropped from TimeOfDay, Date and DateTime types
	else static if (is(T == Date)) return Date.fromISOExtString(value.length > 10 ? value[0..10] : value);
	else static if (is(T == DateTime)) return DateTime.fromISOExtString(value.length > 19 ? value[0..19] : value);
	else static if (is(T == TimeOfDay)) return TimeOfDay.fromISOExtString(value.length > 8 ? value[0..8] : value);
	else static if (is(T == SysTime)) return SysTime.fromISOExtString(value);

	// default conversion
	else return value.to!T;
}

@("Single text value")
@system unittest
{
	`<foo>bar</foo>`.deserialize!string.shouldEqual("bar");
}

@("Single int number")
@system unittest
{
	`<foo>42</foo>`.deserialize!int.shouldEqual(42);
}

@("Single float number")
@system unittest
{
	`<foo>42.1</foo>`.deserialize!double.shouldEqual(42.1);
}

@("Single bool")
@system unittest
{
	`<foo>true</foo>`.deserialize!bool.shouldBeTrue;
	`<foo>false</foo>`.deserialize!bool.shouldBeFalse;
	`<foo>1</foo>`.deserialize!bool.shouldBeTrue;
	`<foo>0</foo>`.deserialize!bool.shouldBeFalse;
}

@("Single Date value")
@system unittest
{
	`<foo>2002-09-24</foo>`.deserialize!Date.shouldEqual(Date(2002, 9, 24));
	`<foo>2002-09-24+06:00</foo>`.deserialize!Date.shouldEqual(Date(2002, 9, 24));
	`<foo>2002-09-24Z</foo>`.deserialize!Date.shouldEqual(Date(2002, 9, 24));
}

@("Single TimeOfDay value")
@system unittest
{
	`<foo>09:01:42</foo>`.deserialize!TimeOfDay.shouldEqual(TimeOfDay(9, 1, 42));
	`<foo>09:30:10Z</foo>`.deserialize!TimeOfDay.shouldEqual(TimeOfDay(9, 30, 10));
	`<foo>09:30:10-06:00</foo>`.deserialize!TimeOfDay.shouldEqual(TimeOfDay(9, 30, 10));
}

@("Single SysTime value")
@system unittest
{
	`<foo>2002-05-30T09:00:00</foo>`.deserialize!DateTime.shouldEqual(DateTime(2002, 5, 30, 9, 0, 0));
	`<foo>2002-05-30T09:30:10.5</foo>`.deserialize!DateTime.shouldEqual(DateTime(2002, 5, 30, 9, 30, 10));
	`<foo>2002-05-30T09:30:10-06:00</foo>`.deserialize!DateTime.shouldEqual(DateTime(2002, 5, 30, 9, 30, 10));
}

@("Single SysTime value")
@system unittest
{
	import core.time : msecs;
	import std.datetime.timezone : UTC;

	`<foo>2002-05-30T09:00:00</foo>`.deserialize!SysTime.shouldEqual(SysTime(DateTime(2002, 5, 30, 9, 0, 0)));
	`<foo>2002-05-30T09:30:10.5</foo>`.deserialize!SysTime.shouldEqual(SysTime(DateTime(2002, 5, 30, 9, 30, 10), 500.msecs));
	`<foo>2002-05-30T09:30:10-06:00</foo>`.deserialize!SysTime.toUTC.shouldEqual(SysTime(DateTime(2002, 5, 30, 15, 30, 10), UTC()));
}

@("Empty object")
@system unittest
{
	struct Foo {}
	`<foo></foo>`.deserialize!Foo.shouldEqual(Foo.init);
}

@("Simple object with attribute")
@system unittest
{
	struct Product { @xmlAttr int pid; }
	`<product pid="42"/>`.deserialize!Product.shouldEqual(Product(42));
}

@("Simple object with attribute and text value")
@system unittest
{
	struct Food { @xmlAttr string type; @xmlText string value; }
	`<food type="dessert">Ice cream</food>`.deserialize!Food.shouldEqual(Food("dessert", "Ice cream"));
}

@("Simple complex object")
@system unittest
{
	struct Employee { string firstname; string lastname; }
	enum xml = `
		<employee>
			<firstname>John</firstname>
			<lastname>Smith</lastname>
		</employee>`;

	xml.deserialize!Employee.shouldEqual(Employee("John", "Smith"));
}

@("Text value with element")
@system unittest
{
	struct DateVal { @xmlAttr string lang; @xmlText Date dt; }
	struct Desc { @xmlText string val; DateVal date; }
	enum xml = `<description>It happened on<date lang="norwegian">2015-01-02</date></description>`;

	xml.deserialize!Desc.shouldEqual(Desc("It happened on", DateVal("norwegian", Date(2015, 1, 2))));
}
