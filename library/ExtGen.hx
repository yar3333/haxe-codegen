import neko.Lib;
import haxe.macro.Context;
import sys.io.File;
using StringTools;

class ExtGen
{
	public static macro function generate(generatorName:String, outPath:String, ?topLevelPackage:String, ?filterFile:String) : Void
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
		
		var filter = filterFile != null ? File.getContent(filterFile).replace("\r\n", "\n").replace("\r", "\n").split("\n") : [];
		if (topLevelPackage != null && topLevelPackage != "") filter.unshift("+" + topLevelPackage);

		new extgen.Processor(filter, generator);
	}
}
