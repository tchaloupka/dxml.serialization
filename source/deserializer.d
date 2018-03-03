module xmlser.deserializer;

import dxml.parser;
import std.exception : enforce;
import std.experimental.logger;
import std.meta;
import std.range : ElementType, isForwardRange;
import std.traits;
import xmlser.attrs;

T deserialize(T, R)(R input)
{
	static string getSymbolName(alias S)()
	{
		static if (hasUDA!(S, NameAttribute)) return getUDAs!(S, NameAttribute)[0].name;
		else return S.stringof;
	}

	T res = T.init;

	static if(isForwardRange!R && isSomeChar!(ElementType!R)) auto range = parseXML(input);
	else alias range = input;

	enforce!XMLDeserializationException(!range.empty, "Xml range is already empty. Cannot deserialize " ~ T.stringof);
	enforce!XMLDeserializationException(range.front.type == EntityType.elementStart, "ElementStart is expected");

	static if (is(T == struct))
	{
		// read attributes
		alias attrFields = getSymbolsByUDA!(T, AttrAttribute);
		static if (attrFields.length)
		{
			foreach (attr; range.front.attributes)
			{
				Lsw: switch (attr.name)
				{
					static foreach(i; 0..attrFields.length)
					{
						case getSymbolName!(attrFields[i]):
							__traits(getMember, res, attrFields[i].stringof) = attr.value;
							break Lsw;
					}
					default:
						logf("Skipping attribute: %s.%s", range.front.name, attr.name);
						break;
				}
			}
		}

		foreach (member;  __traits(derivedMembers, T))
		{
			static if (!hasUDA!(__traits(getMember, res, member), AttrAttribute)) //skip members with AttrAttribute
			{
				enum isMemberVariable = is(typeof(() {
					__traits(getMember, res, member) = __traits(getMember, res, member).init;
				}));
				static if (isMemberVariable)
				{
					pragma(msg, member);
				}
			}
		}
	}

	logf("Element type: %s, name: %s", range.front.type, range.front.name);

	return res;
}

class XMLDeserializationException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}
