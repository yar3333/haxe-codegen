import neko.Lib;
import haxe.macro.Context;
import sys.io.File;
using StringTools;

class ExtGen
{
	public static macro function generate(generatorName:String, outPath:String, ?topLevelPackage:String, ?filterFile:String, ?mapperFile:String) : Void
	{
		var generator = switch (generatorName)
		{
			case "haxe-extern": new extgen.HaxeExternGenerator(outPath);
			case "typescript-extern": new extgen.TypeScriptExternGenerator(outPath);
			case _: Context.fatalError("Unknow generator '" + generatorName + "'. Supported values: 'haxe-extern', 'typescript-extern'.", Context.currentPos());
		};
		
		Lib.println("generator: " + generatorName);
		Lib.println("outPath: " + outPath);
		Lib.println("topLevelPackage: " + (topLevelPackage != null ? topLevelPackage : "not specified"));
		Lib.println("filterFile: " + (filterFile != null ? filterFile : "not specified"));
		Lib.println("mapperFile: " + (mapperFile != null ? mapperFile : "not specified"));
		
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

		new extgen.Processor(generator, filter, mapper);
	}
}
