package codegen;

import haxe.io.Path;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
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
	
	public static function mapType(mapper:Array<{ from:String, to:String }>, tp:TypePath)
	{
		var from = Tools.typePathToString(tp);
		
		for (m in mapper)
		{
			if (m.from == from) Tools.stringToTypePath(m.to, tp);
		}
		
		for (m in mapper)
		{
			if (from.startsWith(m.from + ".")) Tools.stringToTypePath(m.to + from.substring(m.from.length), tp);
		}
	}
	
	/**
	 * Rename types using @:native. Remove that meta after all.
	 */
	public static function applyNatives(types:Array<TypeDefinitionEx>)
	{
		var mapper = new Array<{ from:String, to:String }>();
		var modules = new Map<String, String>();
		
		for (tt in types)
		{
			var native = tt.meta.filter(function(m) return m.name == ":native");
			if (native.length > 0)
			{
				var to = ExprTools.getValue(native[native.length - 1].params[0]);
				mapper.push({ from:(tt.module != "" ? tt.module + "." : "") + tt.name, to:to });
				
				tt.meta = tt.meta.filter(function(m) return m.name != ":native");
				
				var oldModule = tt.module;
				applyFullTypeNameToTypeDefinition(to, tt);
				if (tt.module != oldModule) modules.set(oldModule, tt.module);
			}
		}
		
		for (tt in types)
		{
			if (modules.exists(tt.module)) tt.module = modules.get(tt.module);
		}
		
		Patcher.run(types, mapType.bind(mapper));
	}
	
	static function applyFullTypeNameToTypeDefinition(s:String, tt:TypeDefinitionEx) : Void
	{
		var p = s.split(".");
		if (p.length == 1)
		{
			tt.module = s;
			tt.pack = [];
		}
		else
		if (~/^A-Z/.match(p[p.length - 2]))
		{
			tt.module = p.slice(0, p.length - 1).join(".");
			tt.pack = p.slice(0, p.length - 2);
		}
		else
		{
			tt.module = s;
			tt.pack = p.slice(0, p.length - 1);
		}
		tt.name = p[p.length - 1];
	}
}