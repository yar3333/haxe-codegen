package extgen;

import haxe.io.Path;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;
using Lambda;

class Tools
{
	public static function makeClassesExternAndRemovePriveFields(types:Array<TypeDefinitionEx>)
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
	
	public static function saveFileContent(path:String, content:String)
	{
		var dir = Path.directory(path);
		if (dir != "" && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		File.saveContent(path, content);
	}
	
	public static function mapBaseTypes(types:Array<TypeDefinitionEx>, map:Map<String, String>)
	{
		for (type in types)
		{
			switch (type.kind)
			{
				case TypeDefKind.TDAbstract(t, from, to):
					mapBaseTypesInComplexType(map, t);
					if (from != null) from.iter(mapBaseTypesInComplexType.bind(map));
					if (to != null) to.iter(mapBaseTypesInComplexType.bind(map));
					
				case TypeDefKind.TDAlias(t):
					mapBaseTypesInComplexType(map, t);
					
				case TypeDefKind.TDClass: // nothing to do
				case TypeDefKind.TDEnum: // nothing to do
				case TypeDefKind.TDStructure: // nothing to do
			}
			
			if (type.fields != null) type.fields.iter(mapBaseTypesInField.bind(map));
		}
	}
	
	static function mapBaseTypesInComplexType(map:Map<String, String>, ct:ComplexType)
	{
		if (ct == null) return;
		
		switch (ct)
		{
			case ComplexType.TPath(p):
				mapBaseTypesInTypePath(map, p);
				
			case ComplexType.TFunction(args, ret):
				args.iter(mapBaseTypesInComplexType.bind(map));
				mapBaseTypesInComplexType(map, ret);
				
			case ComplexType.TAnonymous(fields):
				fields.iter(mapBaseTypesInField.bind(map));
				
			case ComplexType.TParent(t):
				mapBaseTypesInComplexType(map, t);
				
			case ComplexType.TExtend(p, fields):
				p.iter(mapBaseTypesInTypePath.bind(map));
				fields.iter(mapBaseTypesInField.bind(map));
				
			case ComplexType.TOptional(t):
				mapBaseTypesInComplexType(map, t);
		}
	}
	
	static function mapBaseTypesInField(map:Map<String, String>, field:Field)
	{
		switch (field.kind)
		{
			case FieldType.FFun(f):
				for (arg in f.args) mapBaseTypesInComplexType(map, arg.type);
				mapBaseTypesInComplexType(map, f.ret);
				
			case FieldType.FProp(_, _, t, _):
				mapBaseTypesInComplexType(map, t);
				
			case FieldType.FVar(t, _):
				mapBaseTypesInComplexType(map, t);
		}
	}
	
	static function mapBaseTypesInTypePath(map:Map<String, String>, tp:TypePath)
	{
		var path = tp.pack.concat([tp.name]);
		if (tp.sub != null) path.push(tp.sub);
		
		var to = map.get(path.join("."));
		if (to != null)
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
}