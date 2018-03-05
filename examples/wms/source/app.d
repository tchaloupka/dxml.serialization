import dxml.serialization : deserialize;
import std.file;
import std.stdio;
import vibe.data.json;
import wms.specs;

void main(string[] args)
{
	if (args.length != 2)
	{
		writeln("Please provide the XML file name");
		return;
	}

	auto doc = readText(args[1]);
	auto caps = doc.deserialize!Capabilities;

	writeln(caps.serializeToJson.toPrettyString);
}
