import std.file;
import std.stdio;

import xmlser.deserializer;
import xmlser.wms;

void main()
{
	auto doc = readText("docs/hrdlicka.xml");

	auto caps = doc.deserialize!Capabilities;

	writeln(caps);
}
