package codegen;

import haxe.io.Path;
import haxe.macro.Expr;
using StringTools;

class HaxeExternGenerator implements IGenerator
{
    public var language(default, never) = "haxe";
    public var isApplyNatives(default, never) = false;
    public var nodeModule(default, null): String;

	static var stdTypeMetasToRemove =
	[
		":expose"
	];
	
	static var stdFieldMetasToRemove =
	[
		":has_untyped",
		":maybeUsed",
		":value",
        ":noapi_typescript",
        ":property"
	];
	
	var outPath : String;
	var badTypeMetas : Array<String>;
	var badFieldMetas : Array<String>;
	
	public function new(outPath:String, nodeModule:String, typeMetasToRemove:Array<String>, fieldMetasToRemove:Array<String>)
	{
		this.outPath = outPath;
		this.nodeModule = nodeModule;
		this.badTypeMetas = stdTypeMetasToRemove.concat(typeMetasToRemove);
		this.badFieldMetas = stdFieldMetasToRemove.concat(fieldMetasToRemove);
	}
	
	public function generate(types:Array<TypeDefinitionEx>)
	{
		for (type in types) type.meta = type.meta.filter(x -> badTypeMetas.indexOf(x.name) < 0);
		
		Tools.markAsExtern(types);
		Tools.removeInlineMethods(types);
        Tools.overloadsToMeta(types);
		
		Patcher.run
		(
			types,
			function(field:Field) : Void
			{
				for (meta in badFieldMetas) Tools.removeFieldMeta(field, meta);
			}
		);
		
		var modules = Tools.separateByModules(types);
		for (module in modules.keys())
		{
			var texts = [];
			
			for (tt in modules.get(module))
			{
				texts.push
				(
					(tt.doc != null && tt.doc != "" ? "/**\n " + tt.doc.trim().split("\n").map(StringTools.trim).join("\n ")  + "\n */\n" : "")
					+ new HaxePrinter().printTypeDefinition(tt, false)
				);
			}

			var pack = Path.directory(module.replace(".", "/")).replace("/", ".");
			
			Tools.saveFileContent
			(
				outPath + "/" + module.replace(".", "/") + ".hx",
				(pack != "" ? "package " + pack + ";\n\n" : "") + texts.join("\n\n")
			);
		}
	}
}
