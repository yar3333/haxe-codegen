package codegen;

import haxe.io.Path;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import sys.FileSystem;
import sys.io.File;
using StringTools;
using Lambda;

class Tools
{
	public static function markAsExtern(types:Array<TypeDefinitionEx>)
	{
		for (tt in types)
		{
			switch (tt.kind)
			{
				case TypeDefKind.TDClass(_, _, isInterface):
					if (!isInterface) tt.isExtern = true;
					for (f in tt.fields) f.access = f.access.filter(function(a) return a != Access.APublic);
					
				case TypeDefKind.TDEnum:
					tt.isExtern = true;
					
				case _:
			};
		}
	}
	
	public static function removeInlineMethods(types:Array<TypeDefinitionEx>)
	{
		for (tt in types)
		{
			switch (tt.kind)
			{
				case TypeDefKind.TDClass(_, _, _):
					tt.fields = tt.fields.filter(function(f) return !f.access.has(Access.AInline));
					
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
			if (from.startsWith(m.from + ".")) Tools.stringToTypePath((m.to != "" ? m.to + "." : "") + from.substring(m.from.length + 1), tp);
		}
	}
	
	public static function extractNativesMapper(types:Array<Type>) : Array<{ from:String, to:String }>
	{
		var r = new Array<{ from:String, to:String }>();
		
		for (type in types)
		{
			switch (type)
			{
                case TInst(t, params):
                    var tt = t.get();
                    if (tt.meta.has(":native"))
                    {
                        var nativeMeta = tt.meta.get().find(x -> x.name == ":native");
                        r.push({ from:getFullClassName(tt), to:ExprTools.getValue(nativeMeta.params[0]) });
                    }

                case _:
            }
		}
		
		return r;
	}
	
	public static function mapTypeDefs(types:Array<TypeDefinitionEx>, mapper:Array<{ from:String, to:String }>)
	{
		var modules = new Map<String, String>();
		
		for (type in types)
		{
			var mappings = mapper.filter(x -> (getFullTypeName(type) + ".").startsWith(x.from + "."));
			if (mappings.length > 0)
			{
				var mapping = mappings[mappings.length - 1];
				var to = (mapping.to != "" ? mapping.to + "." : "") + getFullTypeName(type).substring(mapping.from.length + 1);
				var oldModule = type.module;
				applyFullTypeNameToTypeDefinition(to, type);
				if (type.module != oldModule) modules.set(oldModule, type.module);
			}
		}
		
		for (type in types)
		{
			if (modules.exists(type.module)) type.module = modules.get(type.module);
		}
	}
	
	public static function addJsRequireMeta(types:Array<TypeDefinitionEx>, module:String)
	{
		for (tt in types)
		{
			switch (tt.kind)
			{
				case TypeDefKind.TDClass(_, _, _), TypeDefKind.TDEnum:
					var metas = tt.meta.filter(function(m) return m.name == ":jsRequire");
					if (metas.length == 0)
					{
                        var fullName = (tt.pack != null && tt.pack.length > 0 ? tt.pack.join(".") + "." : "") + tt.name;
						tt.meta.push({	name:":jsRequire", params:[ macro $v{module}, macro $v{fullName} ], pos:null });
					}
					
				case _:
			}
		}
	}
	
	public static function removeFieldMeta(field:Field, meta:String)
	{
		var i = 0; while (i < field.meta.length)
		{
			if (field.meta[i].name == meta) field.meta.splice(i, 1);
			else i++;
		}
	}
	
	public static function getShortClassName(fullClassName:String) : String
	{
		var n = fullClassName.lastIndexOf(".");
		return n < 0 ? fullClassName : fullClassName.substring(n + 1);
	}
	
	public static function getFullClassName(klass:ClassType) : String
	{
		return klass.pack.concat([klass.name]).join(".");
	}
	
	static function getFullTypeName(tt:{ module:String, name:String }) : String
	{
		if (tt.module == tt.name) return tt.name;
		if (tt.module.endsWith("." + tt.name)) return tt.module;
		return tt.module + "." + tt.name;
	} 
	
	static function applyFullTypeNameToTypeDefinition(fullTypeName:String, type:TypeDefinitionEx) : Void
	{
		var p = fullTypeName.split(".");
		if (p.length == 1)
		{
			type.module = fullTypeName;
			type.pack = [];
		}
		else
		if (~/^A-Z/.match(p[p.length - 2]))
		{
			type.module = p.slice(0, p.length - 1).join(".");
			type.pack = p.slice(0, p.length - 2);
		}
		else
		{
			type.module = fullTypeName;
			type.pack = p.slice(0, p.length - 1);
		}
		type.name = p[p.length - 1];
	}
}
