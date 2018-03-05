module dxml.serialization.deserializer;

import dxml.parser;
import dxml.serialization.attrs;
import std.conv : to;
import std.exception : enforce;
import std.experimental.logger;
import std.format : format;
import std.meta;
import std.range : ElementType, isForwardRange;
import std.traits;
import std.typecons : Nullable;

T deserialize(T, R)(R input) if (isForwardRange!R && isSomeChar!(ElementType!R))
{
	auto r = parseXML!simpleXML(input);

	enforce!XMLDeserializationException(!r.empty, "Xml range is already empty. Cannot deserialize " ~ T.stringof);

	assert(r.front.type == EntityType.elementStart);

	Context ctx;
	ctx.path = r.front.name;
	return deserialize!T(r, ctx);
}

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
if (is(R : EntityRange!(C), C...) && ((is(T == struct) && !is(T : Nullable!U, U)) || is(T == class)))
{
	static if (is(T == struct)) T res = T.init;
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

				if (range.front.type == EntityType.elementStart)
				{
					if (isMemberName(range.front.name, mname))
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
				else if (range.front.type == EntityType.text)
				{
					static if (isTextValue!sym)
					{
						static assert (isSomeString!mtype, "Text attribute valid only for string types");
						__traits(getMember, res, member) = range.front.text;
						range.popFront();
					}
					else enforce!XMLDeserializationException(false, format!"Unexpected EntityType: %s"(range.front.type));
				}
				else if (range.front.type == EntityType.elementEnd)
				{
					enforce!XMLDeserializationException(opt, format!"Missing non optional element %s.%s"(ctx.path, mname));
				}
			}
		}
	}

	enforce!XMLDeserializationException(!range.empty, "Xml range is already empty. Cannot deserialize " ~ T.stringof);

	if (!range.empty)
	{
		enforce!XMLDeserializationException(
			range.front.type == EntityType.elementEnd,
			format!"Unexpected elements at the end of %s"(ctx.path)
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

/// Enum type deserialization
T deserializeImpl(T, R)(ref R range, ref Context ctx) if (is(T == enum))
{
	range.popFront();
	T res = range.front.text.to!T;
	range.popFront();
	range.popFront();
	return res;
}

/// Numeric type deserialization
T deserializeImpl(T, R)(ref R range, ref Context ctx) if (isNumeric!T && !is(T == enum))
{
	range.popFront();
	T res = range.front.text.to!T;
	range.popFront();
	range.popFront();
	return res;
}

/// Bool type deserialization
T deserializeImpl(T, R)(ref R range, ref Context ctx) if (is(T == bool))
{
	range.popFront();
	range.front.text.parse!T;
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

T parse(T)(string value) if(is(T == bool))
{
	if (value == "0") return false;
	if (value == "1") return true;
	return value.to!bool;
}

T parse(T)(string value) if(!is(T == bool))
{
	return value.to!T;
}
