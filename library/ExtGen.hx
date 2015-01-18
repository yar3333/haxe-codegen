import neko.Lib;
import haxe.macro.Context;
import sys.io.File;
using StringTools;

class ExtGen
{
	public static macro function generate(generatorName:String, outDir:String, ?topLevelPackage:String, ?include:String, ?exclude:String) : Void
	{
		var generator = switch (generatorName)
		{
			case "haxe-extern": new extgen.GeneratorHaxeExtern(outDir);
			case _: Context.fatalError("Unknow generator '" + generatorName + "'. Supported values: 'haxe-extern'.", Context.currentPos());
		};
		
		Lib.println("generator: " + generatorName);
		Lib.println("outDir: " + outDir);
		Lib.println("topLevelPackage: " + (topLevelPackage != null ? topLevelPackage : "not specified"));
		Lib.println("include: " + (include != null ? include : "not specified"));
		Lib.println("exclude: " + (exclude != null ? exclude : "not specified"));
		
		new extgen.Processor
		(
			topLevelPackage,
			include != null && include.startsWith("regex:") ? new EReg(include.substring("regex:".length), "") : null,
			exclude != null && exclude.startsWith("regex:") ? new EReg(exclude.substring("regex:".length), "") : null,
			include != null && !include.startsWith("regex:") ? File.getContent(include).replace("\r\n", "\n").replace("\r", "\n").split("\n") : null,
			exclude != null && !exclude.startsWith("regex:") ? File.getContent(exclude).replace("\r\n", "\n").replace("\r", "\n").split("\n") : null,
			generator
		);
	}
}
