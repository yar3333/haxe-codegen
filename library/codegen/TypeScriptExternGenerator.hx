package codegen;

import haxe.macro.Expr;
using StringTools;

class TypeScriptExternGenerator implements IGenerator
{
    public var language(default, never) = "typescript";
    public var isApplyNatives(default, never) = true;
    public var nodeModule(default, null): String = null;

	static var typeMap =
	[
		"Float" => "number",
		"Int" => "number",
		"Bool" => "boolean",
		"Dynamic" => "any",
		"Void" => "void",
		"String" => "string",
        "Class" => "any",
        "haxe.extern.EitherType" => "any",
	];
	
	var outPath : String;
	
	public function new(outPath:String)
	{
		this.outPath = outPath;
	}
	
	public function generate(types:Array<TypeDefinitionEx>)
	{
		Tools.markAsExtern(types);
		Tools.removeInlineMethods(types);
        Tools.makeGetterSetterPublic(types);
        Tools.removeFictiveProperties(types);

		Patcher.run
		(
			types,
			
			(tp:TypePath) ->
			{
				var to = typeMap.get(Tools.typePathToString(tp));
				if (to != null) Tools.stringToTypePath(to, tp);
				
				if (to == "any") tp.params = [];
				
				return null;
			},
			
			(field:Field) ->
			{
				if (field.name == "new")
				{
					field.name = "constructor";
					switch (field.kind)	{ case FieldType.FFun(f): f.ret = null; case _: }
				}
			}
		);
		
		var blocks = [];
		
		var packs = Tools.separateByPackages(types);
		for (pack in packs.keys())
		{
			var texts = [];
			for (tt in packs.get(pack))
			{
				texts.push
				(
					(tt.doc != null && tt.doc != "" ? "/**\n " + tt.doc.trim().split("\n").map(StringTools.trim).join("\n ")  + "\n */\n" : "")
					+ new TypeScriptPrinter().printTypeDefinition(tt, false)
				);
			}

			var tab = pack != "" ? "\t" : "";
			blocks.push((pack != "" ? "export namespace " + pack + "\n{\n" : "") + tab + texts.join("\n\n").replace("\n", "\n" + tab) + (pack != "" ? "\n}" : ""));
		}
		
		Tools.saveFileContent(outPath, blocks.join("\n\n"));
	}
}
