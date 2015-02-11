import codegen.IGenerator;
import haxe.io.Path;
import haxe.macro.Context;
import sys.FileSystem;
import sys.io.File;
using StringTools;

class CodeGen
{
	public static macro function haxeExtern(?outPath:String, ?applyNatives:Bool, ?topLevelPackage:String, ?filterFile:String, ?mapperFile:String) : Void
	{
		if (outPath == null || outPath == "") outPath = "hxclasses";
		if (applyNatives == null) applyNatives = false;
		
		Sys.println("generator: haxe extern");
		Sys.println("outPath: " + outPath);
		Sys.println("applyNatives: " + applyNatives);
		
		generate(new codegen.HaxeExternGenerator(outPath), applyNatives, topLevelPackage, filterFile, mapperFile);
	}
	
	public static macro function typescriptExtern(?outPath:String, ?topLevelPackage:String, ?filterFile:String, ?mapperFile:String) : Void
	{
		if (outPath == null || outPath == "") outPath = "tsclasses.d.ts";
		
		Sys.println("generator: typescript extern");
		Sys.println("outPath: " + outPath);
		
		generate(new codegen.TypeScriptExternGenerator(outPath), true, topLevelPackage, filterFile, mapperFile);
	}
	
	static function generate(generator:IGenerator, applyNatives:Bool, topLevelPackage:String, filterFile:String, mapperFile:String) : Void
	{
		Sys.println("topLevelPackage: " + (topLevelPackage != null ? topLevelPackage : "not specified"));
		Sys.println("filterFile: " + (filterFile != null ? filterFile : "not specified"));
		Sys.println("mapperFile: " + (mapperFile != null ? mapperFile : "not specified"));
		Sys.println("applyNatives: " + applyNatives);
		Sys.println("");
		
		preserveOverloads();
		
		var filter = filterFile != null ? File.getContent(filterFile).replace("\r\n", "\n").replace("\r", "\n").split("\n") : [];
		if (topLevelPackage != null) filter.unshift("+" + topLevelPackage);
		
		var mapper = new Array<{ from:String, to:String }>();
		if (mapperFile != null)
		{
			var lines = File.getContent(mapperFile).replace("\r\n", "\n").replace("\r", "\n").split("\n");
			for (s in lines)
			{
				s = s.trim();
				if (s == "" || s.startsWith("#") || s.startsWith("//")) continue;
				
				var m = s.split("=>");
				if (m.length == 2)
				{
					var from  = m[0].trim();
					var to = m[1].trim();
					if (from != "" && to != "")
					{
						mapper.push({ from:from, to:to });
					}
					else
					{
						Context.fatalError("Mapper: bad type format '" + s+ "'.", Context.currentPos());
					}
				}
				else
				{
					Context.fatalError("Mapper: bad type format '" + s+ "'.", Context.currentPos());
				}
			}
		}
		
		new codegen.Processor(generator, applyNatives, filter, mapper);
	}
	
	static function preserveOverloads() : Void
	{
		var tempDir = Path.removeTrailingSlashes(Sys.getEnv("temp")).replace("\\", "/");
		tempDir += "/CodeGen_" + Math.round(Sys.time() * 1000) + "_"  + Std.random(10000);
		
		var processedFiles = new Map<String, Bool>();
		for (classPath in Context.getClassPath())
		{
			classPath = Path.removeTrailingSlashes(classPath).replace("\\", "/");
			if (classPath != "")
			{
				preserveOverloadsProcessDir(classPath, "", processedFiles, tempDir);
			}
		}
		
		if (FileSystem.exists(tempDir))
		{
			haxe.macro.Compiler.addClassPath(tempDir);
			Context.onGenerate(function(_) deleteDirectory(tempDir));
		}
	}
	
	static function preserveOverloadsProcessDir(classPath:String, relDirPath:String, processedFiles:Map<String, Bool>, tempDir:String) : Void
	{
		for (file in FileSystem.readDirectory(classPath + (relDirPath != "" ? "/" + relDirPath : "")))
		{
			var path = (relDirPath != "" ? relDirPath + "/" : "") + file;
			if (FileSystem.isDirectory(classPath + "/" + path))
			{
				preserveOverloadsProcessDir(classPath, path, processedFiles, tempDir);
			}
			else
			{
				if (!processedFiles.exists(path))
				{
					processedFiles.set(path, true);
					var text = File.getContent(classPath + "/" + path);
					var newText = "";
					var n : Int;
					while ((n=text.indexOf("@:overload")) >= 0)
					{
						newText += text.substring(0, n + "@:overload".length);
						text = text.substring(n + "@:overload".length);
						while (text.charAt(0) == " " || text.charAt(0) == "\t")
						{
							newText += text.charAt(0);
							text = text.substring(1);
						}
						newText += "(";
						text = text.substring(1);
						var finish = findClosedBracket(text);
						newText += text.substring(0, finish);
						newText += " @:real_overload(" + text.substring(0, finish);
						text = text.substring(finish);
					}
					newText += text;
					
					if (newText != text)
					{
						var destDir = tempDir + "/" + Path.directory(path);
						if (destDir != "" && !FileSystem.exists(destDir))
						{
							FileSystem.createDirectory(destDir);
						}
						File.saveContent(tempDir + "/" + path, newText);
					}
				}
			}
		}
	}
	
	static function findClosedBracket(text:String) : Int
	{
		var opened = 1;
		for (i in 0...text.length)
		{
			if (text.charAt(i) == ")")
			{
				opened--;
				if (opened == 0) return i + 1;
			}
			else
			if (text.charAt(i) == "(")
			{
				opened++;
			}
		}
		return -1;
	}
	
	static function deleteDirectory(path:String)
    {
        if (FileSystem.exists(path))
		{
			for (file in FileSystem.readDirectory(path))
			{
				if (FileSystem.isDirectory(path + "/" + file))
				{
					deleteDirectory(path + "/" + file);
				}
				else
				{
					FileSystem.deleteFile(path + "/" + file);
				}
			}
			FileSystem.deleteDirectory(path);
		}
    }
}
