package codegen;

import haxe.io.Path;
import haxe.macro.Expr;
using StringTools;

class HaxeExternGenerator implements IGenerator
{
	static var stdTypeMetasToRemove =
	[
		":expose"
	];
	
	static var stdFieldMetasToRemove =
	[
		":has_untyped",
		":maybeUsed",
		":value"
	];
	
	var outPackage : String;
	var outPath : String;
	var badTypeMetas : Array<String>;
	var badFieldMetas : Array<String>;
	
	public function new(outPackage:String, outPath:String, typeMetasToRemove:Array<String>, fieldMetasToRemove:Array<String>)
	{
		this.outPackage = outPackage;
		this.outPath = outPath;
		this.badTypeMetas = stdTypeMetasToRemove.concat(typeMetasToRemove);
		this.badFieldMetas = stdFieldMetasToRemove.concat(fieldMetasToRemove);
	}
	
	public function generate(types:Array<TypeDefinitionEx>)
	{
		for (type in types) type.meta = type.meta.filter(x -> badTypeMetas.indexOf(x.name) < 0);
		
		Tools.markAsExtern(types);
		Tools.removeInlineMethods(types);
		
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

            var prefixedModule = (outPackage != null && outPackage != "" ? outPackage + "." : "") + module;
			
			var pack = Path.directory(prefixedModule.replace(".", "/")).replace("/", ".");
			
			Tools.saveFileContent
			(
				outPath + "/" + prefixedModule.replace(".", "/") + ".hx",
				(pack != "" ? "package " + pack + ";\n\n" : "") + texts.join("\n\n")
			);
		}
	}
}
