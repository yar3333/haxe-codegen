package codegen;

import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.io.File;
using StringTools;

class Manager
{
	public static var platforms = [ "cpp", "cs", "flash", "java", "js", "neko", "php", "python" ];
	
	public static function generate(generator:IGenerator, filterFile:String, mapperFile:String, includePrivate:Bool, filter:Array<String>, mapper:Array<{ from:String, to:String }>, verbose:Bool) : Void
	{
		if (filter == null) filter = [];
		if (mapper == null) mapper = [] else mapper = mapper.copy();
        includePrivate = !!includePrivate;
		
		if (verbose)
		{
			Sys.println("includePrivate: " + includePrivate);
			if (generator.nodeModule != null && generator.nodeModule != "") Sys.println("nodeModule: " + generator.nodeModule);
			if (filterFile != null && filterFile != "") Sys.println("filterFile: " + filterFile);
			if (mapperFile != null && mapperFile != "") Sys.println("mapperFile: " + mapperFile);
            Sys.println("");
		}
		
		filter = filter.concat(filterFile != null ? File.getContent(filterFile).replace("\r\n", "\n").replace("\r", "\n").split("\n") : []);
        filter = filter.filter(x -> x != null).map(x -> x.trim()).filter(x -> x != "" && !x.startsWith("#") && !x.startsWith("//"));

        var includePackAndModules = filter.filter(x -> x.startsWith("+")).map(x -> x.substring(1));
        var ignorePacksAndModules = filter.filter(x -> x.startsWith("-")).map(x -> x.substring(1)).map(x -> Tools.isFullNameHasModule(x) ? x : x + ".*");
        for (pack in includePackAndModules)
        {
            if (Tools.isFullNameHasModule(pack)) Context.getModule(pack);
            else Compiler.include(pack, true, ignorePacksAndModules);
        }
		
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
		
		new codegen.Processor(generator, filter, mapper, true, includePrivate);
	}
}
