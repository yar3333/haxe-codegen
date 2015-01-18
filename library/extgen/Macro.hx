package extgen;

import neko.Lib;
import haxe.macro.Context;

class Macro
{
	public static macro function generate(generatorName:String, outDir:String, ?toplevelPackage:String, ?includeRegex:String, ?excludeRegex:String) : Void
	{
		var generator = switch (generatorName)
		{
			case "haxe-extern": new GeneratorHaxeExtern(outDir);
			case _: Context.fatalError("Unknow generator '" + generatorName + "'. Supported values: 'haxe-extern'.", Context.currentPos());
		};
		
		Lib.println("generator: " + generatorName);
		Lib.println("outDir: " + outDir);
		Lib.println("toplevelPackage: " + (toplevelPackage != null ? toplevelPackage : "not specified"));
		Lib.println("includeRegex: " + (includeRegex != null ? includeRegex : "not specified"));
		Lib.println("excludeRegex: " + (excludeRegex != null ? excludeRegex : "not specified"));
		
		new Processor
		(
			toplevelPackage,
			includeRegex != null ? new EReg(includeRegex, "") : null,
			excludeRegex != null ? new EReg(excludeRegex, "") : null,
			generator
		);
	}
}
