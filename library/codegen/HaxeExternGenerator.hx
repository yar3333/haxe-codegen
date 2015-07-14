package codegen;

import haxe.io.Path;
import haxe.macro.Expr;
using StringTools;

class HaxeExternGenerator implements IGenerator
{
	static var badMetas =
	[
		":has_untyped",
		":value",
		":profile"
	];
	
	var outPath : String;
	
	public function new(outPath:String)
	{
		this.outPath = outPath;
	}
	
	public function generate(types:Array<TypeDefinitionEx>)
	{
		for (type in types) type.meta = type.meta.filter(function(m) return m.name != ":build");
		
		Tools.markAsExtern(types);
		Tools.removeInlineMethods(types);
		
		Patcher.run
		(
			types,
			function(field:Field) : Void
			{
				for (meta in badMetas) Tools.removeFieldMeta(field, meta);
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