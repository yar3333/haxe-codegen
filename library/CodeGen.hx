import codegen.IGenerator;
import neko.Lib;
import haxe.macro.Context;
import sys.io.File;
using StringTools;

class CodeGen
{
	public static macro function haxeExtern(?outPath:String, ?topLevelPackage:String, ?filterFile:String, ?mapperFile:String) : Void
	{
		if (outPath == null || outPath == "") outPath = "hxclasses";
		
		Lib.println("generator: haxeExtern");
		Lib.println("outPath: " + outPath);
		Lib.println("topLevelPackage: " + (topLevelPackage != null ? topLevelPackage : "not specified"));
		Lib.println("filterFile: " + (filterFile != null ? filterFile : "not specified"));
		Lib.println("mapperFile: " + (mapperFile != null ? mapperFile : "not specified"));
		
		generate(new codegen.HaxeExternGenerator(outPath), topLevelPackage, filterFile, mapperFile);
	}
	
	public static macro function typescriptExtern(?outPath:String, ?topLevelPackage:String, ?filterFile:String, ?mapperFile:String) : Void
	{
		if (outPath == null || outPath == "") outPath = "tsclasses.d.ts";
		
		Lib.println("generator: typescriptExtern");
		Lib.println("outPath: " + outPath);
		Lib.println("topLevelPackage: " + (topLevelPackage != null ? topLevelPackage : "not specified"));
		Lib.println("filterFile: " + (filterFile != null ? filterFile : "not specified"));
		Lib.println("mapperFile: " + (mapperFile != null ? mapperFile : "not specified"));
		
		generate(new codegen.TypeScriptExternGenerator(outPath), topLevelPackage, filterFile, mapperFile);
	}
	
	static function generate(generator:IGenerator, outPath:String, ?topLevelPackage:String, ?filterFile:String, ?mapperFile:String) : Void
	{
		var filter = filterFile != null ? File.getContent(filterFile).replace("\r\n", "\n").replace("\r", "\n").split("\n") : [];
		if (topLevelPackage != null && topLevelPackage != "") filter.unshift("+" + topLevelPackage);
		
		var mapper = new Array<{ from:String, to:String }>();
		if (mapperFile != null)
		{
			var lines = File.getContent(mapperFile).replace("\r\n", "\n").replace("\r", "\n").split("\n");
			for (s in lines)
			{
				s = s.trim();
				if (s == "" || s.startsWith("#") || s.startsWith("//")) continue;
				
				var m = s.split("=>");
				if (m.length == 2)
				{
					var from  = m[0].trim();
					var to = m[1].trim();
					if (from != "" && to != "")
					{
						mapper.push({ from:from, to:to });
					}
					else
					{
						Context.fatalError("Mapper: bad type format '" + s+ "'.", Context.currentPos());
					}
				}
				else
				{
					Context.fatalError("Mapper: bad type format '" + s+ "'.", Context.currentPos());
				}
			}
		}

		new codegen.Processor(generator, filter, mapper);
	}
}
