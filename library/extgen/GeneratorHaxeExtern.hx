package extgen;

import neko.Lib;
import haxe.macro.Expr;
import haxe.macro.Printer;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
using StringTools;

/**
 * 
 */
class GeneratorHaxeExtern implements IGenerator
{
	var outDir:String;
	
	public function new(outDir:String) 
	{
		this.outDir = outDir;
	}
	
	public function generate(types:Array<TypeDefinitionAndDoc>)
	{
		for (tt in types)
		{
			switch (tt.kind)
			{
				case TypeDefKind.TDClass:
					tt.isExtern = true;
				case _:
			}
			
			var path = outDir + "/" + tt.pack.concat([ tt.name ]).join("/") + ".hx";
			var dir = haxe.io.Path.directory(path);
			if (dir != "" && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			
			File.saveContent(path, 
				(tt.pack.length > 0 && tt.pack[0] != "" ? "package " + tt.pack.join(".") + ";\n\n" : "")
				+ (tt.doc != null && tt.doc != "" ? "/**\n * " + tt.doc.trim().split("\n").map(StringTools.trim).join("\n * ")  + "\n */\n" : "")
				+ new HaxePrinter().printTypeDefinition(tt, false)
			);
		}
	}
}