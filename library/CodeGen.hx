import haxe.macro.Type.BaseType;
import haxe.macro.Context;
import codegen.Tools;
import codegen.Manager;
using StringTools;

class CodeGen
{
	public static var verbose = false;
	
	public static var includePrivate = false;
	public static var typeMetasToRemove = new Array<String>();
	public static var fieldMetasToRemove = new Array<String>();
	
	static var filters = new Array<String>();
	static var mappers = new Array<{ from:String, to:String }>();

	public static function includePrivateMembers()
	{
        includePrivate = true;
	}
        
    public static function include(pack:String)
	{
		for (p in splitValues(pack)) filters.push("+" + p);
	}
	
	public static function exclude(pack:String)
        {
            for (p in splitValues(pack)) filters.push("-" + p);
        }
        
	public static function removeTypeMeta(meta:String)
	{
		for (m in splitValues(meta)) typeMetasToRemove.push(m);
	}
	
	public static function removeFieldMeta(meta:String)
	{
		for (m in splitValues(meta)) fieldMetasToRemove.push(m);
	}
	
	public static function map(from:String, to:String)
	{
		mappers.push({ from:from, to:to });
	}
	
	public static function haxeExtern(?outPath:String, ?requireNodeModule:String, ?filterFile:String, ?mapperFile:String) : Void
	{
		if (outPath == null || outPath == "") outPath = "hxclasses";
		
		if (verbose)
		{
			Sys.println("generator: haxe extern");
			Sys.println("outPath: " + outPath);
		}
		
        var generator = new codegen.HaxeExternGenerator(outPath, typeMetasToRemove, fieldMetasToRemove);
		Manager.generate(generator, false, filterFile, mapperFile, includePrivate, requireNodeModule, filters, mappers, verbose);
	}
	
	public static function typescriptExtern(?outPath:String, ?filterFile:String, ?mapperFile:String) : Void
	{
		if (outPath == null || outPath == "") outPath = "tsclasses.d.ts";
		
		if (verbose)
		{
			Sys.println("generator: typescript extern");
			Sys.println("outPath: " + outPath);
		}
		
        var generator = new codegen.TypeScriptExternGenerator(outPath);
		Manager.generate(generator, true, filterFile, mapperFile, includePrivate, null, filters, mappers, verbose);
	}

    public static function exposeToRoot(pack:String) : Void
    {
        var packArr = pack.split(".");

        Context.onGenerate(types ->
        {
            for (type in types)
            {
                var klass: BaseType = switch (type)
                {
                    case TInst(t, params): t.get();
                    case TType(t, params): t.get();
                    case TEnum(t, params): t.get();
                    case TAbstract(t, params): t.get();
                    case _: null;
                };
                if (klass != null && Tools.getFullClassName(klass.pack, klass.name).startsWith(pack + "."))
                {
                    var newName = Tools.getFullClassName(klass.pack.slice(packArr.length), klass.name);
                    klass.meta.add(":expose", [ macro $v{newName} ], klass.pos);
                }
            }
        });
    }

	static function splitValues(s:String) : Array<String>
	{
		var r = [];
		for (p in ~/[\t\r\n ,;|]+/g.split(s))
		{
			p = p.trim();
			if (p != "") r.push(p);
		}
		return r;
	}
}
