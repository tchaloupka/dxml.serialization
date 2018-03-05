/++
	Manually written WMS definitions to test XML deserialization in real app

	XSD: http://schemas.opengis.net/wms/1.3.0/capabilities_1_3_0.xsd
	Sample XML: http://schemas.opengis.net/wms/1.3.0/capabilities_1_3_0.xml
+/

module wms.specs;

import dxml.serialization.attrs;
import std.typecons : Nullable;

/// A WMS_Capabilities document is returned in response to a GetCapabilities request made on a WMS.
@xmlName("WMS_Capabilities")
struct Capabilities
{
	@xmlAttr @xmlName("version") string ver = "1.3.0";
	@xmlAttr @xmlOptional string updateSequence;

	/// General service metadata
	Service service;

	/++
		A Capability lists available request types, how exceptions may be
		reported, and whether any extended capabilities are defined.
		It also includes an optional list of map layers available from this
		server.
	+/
	Capability capability;
}

/// General service metadata
struct Service
{
	/// Name of the Service
	ServiceName name;

	/// The Title is for informative display to a human.
	string title;

	/// The abstract is a longer narrative description of an object
	@xmlOptional @xmlName("Abstract")
	string description;

	/// List of keywords or keyword phrases to help catalog searching
	KeywordList keywordList;

	/++
		An OnlineResource is typically an HTTP URL.  The URL is placed in
		the xlink:href attribute, and the value "simple" is placed in the
		xlink:type attribute.
	+/
	OnlineResource onlineResource;

	/// Information about a contact person for the service
	@xmlOptional Nullable!ContactInformation contactInformation;

	@xmlOptional string fees;

	@xmlOptional string accessConstraints;

	@xmlOptional Nullable!uint layerLimit;
	@xmlOptional Nullable!uint maxWidth;
	@xmlOptional Nullable!uint maxHeight;
}

/// List of keywords or keyword phrases to help catalog searching
struct KeywordList
{
	@xmlOptional @xmlName("Keyword") Keyword[] keywords;
}

/// Information about a contact person for the service
struct ContactInformation
{
	@xmlOptional ContactPersonPrimary contactPersonPrimary;
	@xmlOptional string contactPosition;
	@xmlOptional ContactAddress contactAddress;
	@xmlOptional string contactVoiceTelephone;
	@xmlOptional string contactFacsimileTelephone;
	@xmlOptional string contactElectronicMailAddress;
}

struct ContactAddress
{
	string addressType;
	string address;
	string city;
	string stateOrProvince;
	string postCode;
	string country;
}

struct ContactPersonPrimary
{
	string contactPerson;
	string contactOrganization;
}

/++
	An OnlineResource is typically an HTTP URL.  The URL is placed in
	the xlink:href attribute, and the value "simple" is placed in the
	xlink:type attribute.
+/
struct OnlineResource
{
	@xmlAttr @xmlOptional @xmlName("xlink:type") string type = "simple";
	@xmlAttr @xmlOptional @xmlName("xlink:href") string href;
	// @xmlAttr @xmlOptional @xmlName("xlink:role") string role;
	// @xmlAttr @xmlOptional @xmlName("xlink:arcrole") string arcrole;
	// @xmlAttr @xmlOptional @xmlName("xlink:title") string title;
	// @xmlAttr @xmlOptional @xmlName("xlink:show") string show;
	// @xmlAttr @xmlOptional @xmlName("xlink:actuate") string actuate;
}

/// Keyword phrase to help catalog searching
struct Keyword
{
	@xmlAttr @xmlOptional string vocabulary;
	@xmlText string value;
}

/// Name of the Service
enum ServiceName// : string
{
	WMS// = "WMS"
}

/++
	A Capability lists available request types, how exceptions may be
	reported, and whether any extended capabilities are defined.
	It also includes an optional list of map layers available from this
	server.
+/
struct Capability
{
	Request request;
	WmsException exception;
	//TODO: extended
	@xmlName("Layer") Layer[] layers; /// Nested list of zero or more map Layers offered by this server.
}

/// Description of map Layer offered by this server.
struct Layer
{
	@xmlOptional string name;
	string title;
	@xmlOptional @xmlName("Abstract") string description;
	@xmlOptional Nullable!KeywordList keywordList;
	@xmlOptional @xmlName("CRS") string[] crs; /// Supported Coordinate Reference Systems (CRS)

	/// The EX_GeographicBoundingBox attributes indicate the limits of the enclosing rectangle in longitude and latitude decimal degrees.
	@xmlOptional @xmlName("EX_GeographicBoundingBox")
	EX_GeographicBoundingBox geoBoundingBox;

	/// The BoundingBox attributes indicate the limits of the bounding box in units of the specified coordinate reference system.
	@xmlOptional @xmlName("BoundingBox") BoundingBox[] boundingBoxes;
	@xmlOptional Nullable!Dimension dimension;

	@xmlOptional Nullable!Attribution attribution;
	@xmlOptional @xmlName("AuthorityURL") AuthorityURL[] authorityURLs;

	@xmlOptional @xmlName("Identifier") Identifier[] identifiers;
	@xmlOptional @xmlName("MetadataURL") MetadataURL[] metadataURLs;
	@xmlOptional @xmlName("DataURL") DataURL[] dataURLs;
	@xmlOptional @xmlName("FeatureListURL") FeatureListURL[] featureListURLs;
	@xmlOptional @xmlName("Style") Style[] styles;
	@xmlOptional Nullable!double minScaleDenominator; /// Minimum scale denominator for which it is appropriate to display this layer
	@xmlOptional Nullable!double maxScaleDenominator; /// Maximum scale denominator for which it is appropriate to display this layer.
	@xmlOptional @xmlName("Layer") Layer[] layers;

	//attrs
	@xmlAttr @xmlOptional bool queryable = false;
	@xmlAttr @xmlOptional Nullable!uint cascaded;
	@xmlAttr @xmlOptional bool opaque = false;
	@xmlAttr @xmlOptional bool noSubsets = false;
	@xmlAttr @xmlOptional Nullable!uint fixedWidth;
	@xmlAttr @xmlOptional Nullable!uint fixedHeight;
}

/++
	A Style element lists the name by which a style is requested and a
	human-readable title for pick lists, optionally (and ideally)
	provides a human-readable description, and optionally gives a style
	URL.
+/
struct Style
{
	string name;
	@xmlOptional string title; //FIXME: Not supposed to be optional, but Hrdlicka XML doesn't provide it
	@xmlOptional @xmlName("Abstract") string description;
	@xmlName("LegendURL") LegendURL[] legendURLs;
	@xmlOptional Nullable!StyleSheetURL styleSheetURL;
	@xmlOptional Nullable!StyleURL styleURL;
}

/++
	A Map Server may use StyleURL to offer more information about the
	data or symbology underlying a particular Style. While the semantics
	are not well-defined, as long as the results of an HTTP GET request
	against the StyleURL are properly MIME-typed, Viewer Clients and
	Cascading Map Servers can make use of this. A possible use could be
	to allow a Map Server to provide legend information.
+/
struct StyleURL
{
	string format;
	OnlineResource onlineResource;
}

/++
	StyleSheeetURL provides symbology information for each Style of a Layer.
+/
struct StyleSheetURL
{
	string format;
	OnlineResource onlineResource;
}

/++
	A Map Server may use zero or more LegendURL elements to provide an
	image(s) of a legend relevant to each Style of a Layer.  The Format
	element indicates the MIME type of the legend. Width and height
	attributes may be provided to assist client applications in laying out
	space to display the legend.
+/
struct LegendURL
{
	string format;
	OnlineResource onlineResource;
	@xmlAttr @xmlOptional uint width;
	@xmlAttr @xmlOptional uint height;
}

/++
	A Map Server may use FeatureListURL to point to a list of the
	features represented in a Layer.
+/
struct FeatureListURL
{
	string format;
	OnlineResource onlineResource;
}

/++
	A Map Server may use DataURL offer a link to the underlying data represented
	by a particular layer
+/
struct DataURL
{
	string format;
	OnlineResource onlineResource;
}

/++
	A Map Server may use zero or more MetadataURL elements to offer
	detailed, standardized metadata about the data underneath a
	particular layer. The type attribute indicates the standard to which
	the metadata complies.  The format element indicates how the metadata is structured.
+/
struct MetadataURL
{
	string format;
	OnlineResource onlineResource;
	@xmlAttr string type;
}

struct Identifier
{
	@xmlText string value;
	@xmlAttr string authority;
}

/++
	A Map Server may use zero or more Identifier elements to list ID
	numbers or labels defined by a particular Authority.  For example,
	the Global Change Master Directory (gcmd.gsfc.nasa.gov) defines a
	DIF_ID label for every dataset.  The authority name and explanatory
	URL are defined in a separate AuthorityURL element, which may be
	defined once and inherited by subsidiary layers.  Identifiers
	themselves are not inherited.
+/
struct AuthorityURL
{
	OnlineResource onlineResource;
	@xmlAttr string name;
}

/++
	Attribution indicates the provider of a Layer or collection of Layers.
	The provider's URL, descriptive title string, and/or logo image URL
	may be supplied.  Client applications may choose to display one or
	more of these items.  A format element indicates the MIME type of
	the logo image located at LogoURL.  The logo image's width and height
	assist client applications in laying out space to display the logo.
+/
struct Attribution
{
	@xmlOptional string title;
	@xmlOptional Nullable!OnlineResource onlineResource;
	@xmlOptional Nullable!LogoURL logoURL;
}

struct LogoURL
{
	string format;
	OnlineResource onlineResource;
	@xmlAttr uint width;
	@xmlAttr uint height;
}

/// The Dimension element declares the existence of a dimension and indicates what values along a dimension are valid.
struct Dimension
{
	@xmlAttr string name;
	@xmlAttr string units;
	@xmlAttr @xmlOptional string unitSymbol;
	@xmlAttr @xmlOptional @xmlName("default") string def;
	@xmlAttr @xmlOptional Nullable!bool multipleValues;
	@xmlAttr @xmlOptional Nullable!bool nearestValue;
	@xmlAttr @xmlOptional Nullable!bool current;
}

/++
	The BoundingBox attributes indicate the limits of the bounding box
	in units of the specified coordinate reference system.
+/
struct BoundingBox
{
	@xmlAttr @xmlName("CRS") string crs;
	@xmlAttr double minx;
	@xmlAttr double miny;
	@xmlAttr double maxx;
	@xmlAttr double maxy;
	@xmlAttr @xmlOptional Nullable!double resx;
	@xmlAttr @xmlOptional Nullable!double resy;
}

struct EX_GeographicBoundingBox
{
	double westBoundLongitude;
	double eastBoundLongitude;
	double southBoundLatitude;
	double northBoundLatitude;
}

struct WmsException
{
	@xmlName("Format") string[] formats;
}

/// Available WMS Operations are listed in a Request element.
struct Request
{
	OperationType getCapabilities;
	OperationType getMap;
	@xmlOptional Nullable!OperationType getFeatureInfo;

	//TODO: Extended operations
}

/++
	For each operation offered by the server, list the available output
	formats and the online resource.
+/
struct OperationType
{
	@xmlName("Format") string[] formats; /// Supported operation mime types
	@xmlName("DCPType") DCPType[] dcpTypes;
}

/++
	Available Distributed Computing Platforms (DCPs) are listed here.
	At present, only HTTP is defined.
+/
struct DCPType
{
	@xmlName("HTTP") HTTP http;
}

/// Available HTTP request methods.  At least "Get" shall be supported.
struct HTTP
{
	Get get;
	@xmlOptional Nullable!Post post;
}

/// The URL prefix for the HTTP "Get" request method.
struct Get
{
	OnlineResource onlineResource;
}

/// The URL prefix for the HTTP "Post" request method.
struct Post
{
	OnlineResource onlineResource;
}
