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
	public static function markAsExtern(types:Array<TypeDefinitionEx>) : Void
	{
		for (tt in types)
		{
			switch (tt.kind)
			{
				case TypeDefKind.TDClass(_, _, isInterface):
					if (!isInterface) tt.isExtern = true;
					for (f in tt.fields) f.access = f.access.filter(a -> a != Access.APublic);
					
				case TypeDefKind.TDEnum:
					tt.isExtern = true;
					
				case _:
			};
		}
	}
	
	public static function removeInlineMethods(types:Array<TypeDefinitionEx>) : Void
	{
		for (tt in types)
		{
			switch (tt.kind)
			{
				case TypeDefKind.TDClass(_, _, _):
					tt.fields = tt.fields.filter(f -> !f.access.has(Access.AInline));
					
				case _:
			};
		}
	}

    public static function overloadsToMeta(types:Array<TypeDefinitionEx>) : Void
    {
		for (tt in types)
        {
            switch (tt.kind)
            {
                case TypeDefKind.TDClass(_, _, _):
                    for (field in tt.fields)
                    {
                        if (tt.methodOverloads.exists(field.name))
                        {
                            for (m in tt.methodOverloads.get(field.name))
                            {
                                switch (m.kind) 
                                {
                                    case FFun(f): field.meta.push(overloadToMeta(m, f));
                                    case _:
                                }
                            }
                        }
                    }
                case _:
            };
        }
    }

    static function overloadToMeta(method:Field, f:Function) : MetadataEntry
    {
        f.expr = macro {};
        return { name: ":overload", params: [ { expr:EFunction(FunctionKind.FAnonymous, f), pos: method.pos } ], pos: method.pos };
    }

	public static function makeGetterSetterPublic(types:Array<TypeDefinitionEx>) : Void
	{
		for (tt in types)
		{
			switch (tt.kind)
			{
				case TypeDefKind.TDClass(_, _, _):
                    for (f in tt.fields)
                    {
                        if ((f.name.startsWith("get_") || f.name.startsWith("set_")) && tt.fields.exists(x -> x.name == f.name.substr(4) && !(x.access ?? []).contains(APrivate)))
                        {
                            f.access = f.access.filter(x -> x != APrivate);
                            f.access.push(APublic);
                        }
                    }
					
				case _:
			};
		}
	}

	public static function removeFictiveProperties(types:Array<TypeDefinitionEx>) : Void
    {
		for (tt in types)
        {
            switch (tt.kind)
            {
                case TypeDefKind.TDClass(_, _, _):
                    tt.fields = tt.fields.filter(f -> switch (f.kind)
                    {
                        case FProp(get, set): get != "get" || set != "set";
                        case _: true;
                    });
                    
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
			else                    packs.set(pack, [tt]);
		}
		
		return packs;
	}
	
	public static function saveFileContent(path:String, content:String) : Void
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
	
	public static function mapType(mapper:Array<{ from:String, to:String }>, tp:TypePath) : Void
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
                case TInst(t, params):     extractNativesMapperInner(t.get(), r);
                case TType(t, params):     extractNativesMapperInner(t.get(), r);
                case TEnum(t, params):     extractNativesMapperInner(t.get(), r);
                case TAbstract(t, params): extractNativesMapperInner(t.get(), r);
                case _:
            }
		}
		
		return r;
	}

    static function extractNativesMapperInner(tt:{ meta:MetaAccess, pack:Array<String>, name:String, module:String }, r: Array<{ from:String, to:String }>) : Void
    {
        if (tt.meta.has(":native"))
        {
            var nativeMeta = tt.meta.get().find(x -> x.name == ":native");
            r.push({ from:getFullTypeName(tt.name, tt.module), to:ExprTools.getValue(nativeMeta.params[0]) });
        }
        else
        if (tt.meta.has(":expose"))
        {
            var exposeMeta = tt.meta.get().find(x -> x.name == ":expose");
            if (exposeMeta.params.length > 0)
            {
                r.push({ from:getFullTypeName(tt.name, tt.module), to:ExprTools.getValue(exposeMeta.params[0]) });
            }
        }
    }
	
	public static function mapTypeDefs(types:Array<TypeDefinitionEx>, mapper:Array<{ from:String, to:String }>) : Void
	{
		var modules = new Map<String, String>();
		
		for (type in types)
		{
			var mappings = mapper.filter(x -> (getFullTypeName(type.name, type.module) + ".").startsWith(x.from + "."));
			if (mappings.length > 0)
			{
				var mapping = mappings[mappings.length - 1];
				var to = isFullNameHasModule(mapping.to)
                    ? mapping.to
                    : (mapping.to != "" ? mapping.to + "." : "") + getFullTypeName(type.name, type.module).substring(mapping.from.length + 1);
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

    public static function isFullNameHasModule(fullName:String) : Bool
    {
        return ~/^[A-Z]|\.[A-Z]/.match(fullName);
    }
	
	public static function addJsRequireMeta(types:Array<TypeDefinitionEx>, nodeModule:String) : Void
	{
		for (tt in types)
		{
			switch (tt.kind)
			{
				case TypeDefKind.TDClass(_, _, _), TypeDefKind.TDEnum:
					if (!tt.meta.exists(x-> x.name == ":jsRequire"))
					{
                        var expose = tt.meta.find(x-> x.name == ":expose");
                        var fullName = expose != null ? ExprTools.getValue(expose.params[0]) : Tools.getFullTypeName(tt.name, tt.module);                     
						tt.meta.push({	name:":jsRequire", params:[ macro $v{nodeModule}, macro $v{fullName} ], pos:null });
					}
					
				case _:
			}
		}
	}
	
	public static function removeFieldMeta(field:Field, meta:String) : Void
	{
		var i = 0; while (i < field.meta.length)
		{
			if (field.meta[i].name == meta) field.meta.splice(i, 1);
			else i++;
		}
	}
	
	public static function getShortTypeName(fullClassName:String) : String
	{
		var n = fullClassName.lastIndexOf(".");
		return n < 0 ? fullClassName : fullClassName.substring(n + 1);
	}
	
	public static function getFullTypeName(name:String, module:String) : String
	{
		if (getShortTypeName(module) == name) return module;
		return module + "." + name;
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

    public static function concatMaps<K, V>(a:Map<K, V>, b:Map<K, V>) : Map<K, V>
    {
        var r = a.copy();
        for (kv in b.keyValueIterator()) r.set(kv.key, kv.value);
        return r;
    }

    public static function overloadsToFields(types:Array<TypeDefinitionEx>) : Void
    {
        for (tt in types)
        {
            switch (tt.kind)
            {
                case TypeDefKind.TDClass(_, _, _):
                    var fields  = new Array<Field>();
                    for (field in tt.fields)
                    {
                        if (tt.methodOverloads.exists(field.name))
                        {
                            fields = fields.concat(tt.methodOverloads.get(field.name));
                        }
                        fields.push(field);
                    }
                    tt.fields = fields;
                case _:
            };
        }
    }

    public static function orderBy<T, E>(arr:Iterable<T>, fieldSelector:T->E) : Array<T>
    {
        final r = arr.array();
        r.sort((a, b) -> Reflect.compare(fieldSelector(a), fieldSelector(b)));
        return r;
    }
}
