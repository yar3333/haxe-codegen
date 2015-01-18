package extgen;

import neko.Lib;
import haxe.macro.Expr;
import haxe.macro.Printer;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
using StringTools;

class GeneratorHaxeExtern implements IGenerator
{
	var outDir:String;
	
	public function new(outDir:String) 
	{
		this.outDir = outDir;
	}
	
	public function generate(types:Array<TypeDefinitionEx>)
	{
		var modules = new Map<String, Array<TypeDefinitionEx>>();
		
		for (tt in types)
		{
			switch (tt.kind)
			{
				case TypeDefKind.TDClass:
					tt.isExtern = true;
					for (f in tt.fields) f.access = f.access.filter(function(a) return a != Access.APublic);
					
				case _:
			};
			
			if (modules.exists(tt.module)) modules.get(tt.module).push(tt);
			else modules.set(tt.module, [tt]);
		}
		
		for (module in modules.keys())
		{
			var path = outDir + "/" + module.replace(".", "/") + ".hx";
			var dir = haxe.io.Path.directory(path);
			if (dir != "" && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			
			var texts = [];
			for (tt in modules.get(module))
			{
				texts.push
				(
					(tt.doc != null && tt.doc != "" ? "/**\n * " + tt.doc.trim().split("\n").map(StringTools.trim).join("\n * ")  + "\n */\n" : "")
					+ new HaxePrinter().printTypeDefinition(tt, false)
				);
			}
			
			var pack = Path.directory(module.replace(".", "/")).replace("/", ".");
			File.saveContent(path, (pack != "" ? "package " + pack + ";\n\n" : "") + texts.join("\n\n"));
		}
	}
}