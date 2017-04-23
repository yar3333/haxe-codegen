import codegen.Manager;
using StringTools;

class CodeGen
{
	public static var outPath : String = null;
	public static var applyNatives : Bool = null;
	public static var filterFile : String = null;
	public static var mapperFile : String = null;
	public static var includePrivate : Bool = null;
	public static var requireNodeModule : String = null;
	
	static var filters = new Array<String>();
	static var mappers = new Array<{ from:String, to:String }>();
	
	public static function set(property:String, value:Dynamic)
	{
		var fields = Type.getClassFields(CodeGen);
		
		if (fields.indexOf(property) >= 0)
		{
			Reflect.setField(CodeGen, property, value);
		}
		else
		{
			Sys.print("CodeGen.set(): unknow property '" + property + "'. Supported properties: " + fields.join(", ") + ".\r");
		}
	}
	
	public static function include(pack:String)
	{
		for (p in parsePacks(pack)) filters.push("+" + p);
	}
	
	public static function exclude(pack:String)
	{
		for (p in parsePacks(pack)) filters.push("-" + p);
	}
	
	public static function clearFilters()
	{
		filters = [];
	}
	
	public static function map(from:String, to:String)
	{
		mappers.push({ from:from, to:to });
	}
	
	public static function clearMappers()
	{
		mappers = [];
	}
	
	public static function generate(generatorType:String)
	{
		switch (generatorType)
		{
			case "haxeExtern":
				haxeExtern(outPath, applyNatives, null, filterFile, mapperFile, includePrivate, requireNodeModule, filters, mappers);
				
			case "typescriptExtern":
				typescriptExtern(outPath, null, filterFile, mapperFile, includePrivate, filters, mappers);
				
			case _:
				Sys.print("CodeGen.generate(): unknow generator type. Supported types: haxeExtern, typescriptExtern.\r");
		}
	}
	
	public static function haxeExtern(?outPath:String, ?applyNatives:Bool, ?topLevelPackage:String, ?filterFile:String, ?mapperFile:String, ?includePrivate:Bool, ?requireNodeModule:String, ?filters:Array<String>, ?mappers:Array<{ from:String, to:String }>) : Void
	{
		if (outPath == null || outPath == "") outPath = "hxclasses";
		if (applyNatives == null) applyNatives = false;
		
		Sys.print("generator: haxe extern\r");
		Sys.print("outPath: " + outPath + "\r");
		
		Manager.generate(new codegen.HaxeExternGenerator(outPath), applyNatives, topLevelPackage, filterFile, mapperFile, includePrivate, requireNodeModule, filters, mappers);
	}
	
	public static function typescriptExtern(?outPath:String, ?topLevelPackage:String, ?filterFile:String, ?mapperFile:String, ?includePrivate:Bool, ?filters:Array<String>, ?mappers:Array<{ from:String, to:String }>) : Void
	{
		if (outPath == null || outPath == "") outPath = "tsclasses.d.ts";
		
		Sys.print("generator: typescript extern\r");
		Sys.print("outPath: " + outPath + "\r");
		
		Manager.generate(new codegen.TypeScriptExternGenerator(outPath), true, topLevelPackage, filterFile, mapperFile, includePrivate, null, filters, mappers);
	}
	
	static function parsePacks(s:String) : Array<String>
	{
		var r = [];
		for (p in ~/[\t\r\n ,;|]+/g.split(s))
		{
			p = p.trim();
			if (p != "") r.push(p);
		}
		return r;
	}
}
