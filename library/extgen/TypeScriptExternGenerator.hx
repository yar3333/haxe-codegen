package extgen;

import haxe.io.Path;
using StringTools;

class TypeScriptExternGenerator implements IGenerator
{
	var outPath:String;
	
	public function new(outPath:String) 
	{
		this.outPath = outPath;
	}
	
	public function generate(types:Array<TypeDefinitionEx>)
	{
		Tools.makeClassesExternAndRemovePrivateFields(types);
		
		new TypeMapper
		([
			"Float" => "number",
			"Int" => "number",
			"Bool" => "boolean",
			"Dynamic" => "any",
			"Void" => "void",
			"String" => "string"
		])
		.process(types);
		
		new FieldMapper
		([
			"new" => "constructor"
		])
		.process(types);
		
		var blocks = [];
		
		var modules = Tools.separateByModules(types);
		for (module in modules.keys())
		{
			var texts = [];
			for (tt in modules.get(module))
			{
				texts.push
				(
					(tt.doc != null && tt.doc != "" ? "/**\n * " + tt.doc.trim().split("\n").map(StringTools.trim).join("\n * ")  + "\n */\n" : "")
					+ new TypeScriptPrinter().printTypeDefinition(tt, false)
				);
			}
			
			var pack = Path.directory(module.replace(".", "/")).replace("/", ".");
			blocks.push((pack != "" ? "declare module " + pack + "\n{\n" : "") + "\t" + texts.join("\n\n").replace("\n", "\n\t") + (pack != "" ? "\n}" : ""));
		}
		
		Tools.saveFileContent(outPath, blocks.join("\n\n"));
	}
}