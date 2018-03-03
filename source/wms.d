module xmlser.wms;

import xmlser.attrs;

/// A WMS_Capabilities document is returned in response to a GetCapabilities request made on a WMS.
@name("WMS_Capabilities")
struct Capabilities
{
	@attr @name("version") string ver = "1.3.0";
	@attr string updateSequence;
	Service service;
	Capability capability;
}


struct Service
{

}

struct Capability
{

}
