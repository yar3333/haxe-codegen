package codegen;

import haxe.io.Path;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;
using StringTools;
using Lambda;

class Tools
{
	public static function makeClassesExternAndRemovePrivateFields(types:Array<TypeDefinitionEx>)
	{
		for (tt in types)
		{
			switch (tt.kind)
			{
				case TypeDefKind.TDClass:
					tt.isExtern = true;
					for (f in tt.fields) f.access = f.access.filter(function(a) return a != Access.APublic);
					
				case _:
			};
		}
	}
	
	public static function separateByModules(types:Array<TypeDefinitionEx>) : Map<String, Array<TypeDefinitionEx>>
	{
		var modules = new Map<String, Array<TypeDefinitionEx>>();
		
		for (tt in types)
		{
			if (modules.exists(tt.module)) modules.get(tt.module).push(tt);
			else modules.set(tt.module, [tt]);
		}
		
		return modules;
	}
	
	public static function separateByPackages(types:Array<TypeDefinitionEx>) : Map<String, Array<TypeDefinitionEx>>
	{
		var packs = new Map<String, Array<TypeDefinitionEx>>();
		
		for (tt in types)
		{
			var pack = Path.withoutDirectory(tt.module.replace(".", "/")) == tt.name ? tt.pack.join(".") : tt.module;
			if (packs.exists(pack)) packs.get(pack).push(tt);
			else packs.set(pack, [tt]);
		}
		
		return packs;
	}
	
	public static function saveFileContent(path:String, content:String)
	{
		var dir = Path.directory(path);
		if (dir != "" && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		File.saveContent(path, content);
	}
	
	public static function typePathToString(tp:TypePath) : String
	{
		var path = tp.pack.concat([tp.name]);
		if (tp.sub != null) path.push(tp.sub);
		return path.join(".");
	}
	
	public static function stringToTypePath(to:String, tp:TypePath) : Void
	{
		var n = to.lastIndexOf(".");
		if (n < 0)
		{
			tp.pack = [];
			tp.name = to;
		}
		else
		{
			tp.pack = to.substring(0, n).split(".");
			tp.name = to.substring(n + 1);
			
		}
		tp.sub = null;
	}
}