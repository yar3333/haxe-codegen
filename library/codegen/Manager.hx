package codegen;

import haxe.io.Path;
import haxe.macro.Context;
import sys.io.File;
import sys.FileSystem;
using StringTools;

class Manager
{
	public static var platforms = [ "cpp", "cs", "flash", "java", "js", "neko", "php", "python" ];
	
	public static function generate(generator:IGenerator, applyNatives:Bool, filterFile:String, mapperFile:String, includePrivate:Bool, requireNodeModule:String, filter:Array<String>, mapper:Array<{ from:String, to:String }>, verbose:Bool) : Void
	{
		if (filter == null) filter = [];
		if (mapper == null) mapper = [];
		
		if (verbose)
		{
			Sys.println("applyNatives: " + applyNatives);
			Sys.println("includePrivate: " + (!!includePrivate));
			Sys.println("requireNodeModule: " + (requireNodeModule != null ? requireNodeModule : "-"));
			Sys.println("filterFile: " + (filterFile != null ? filterFile : "-"));
			Sys.println("mapperFile: " + (mapperFile != null ? mapperFile : "-"));
            Sys.println("");
		}
		
		preserveOverloads();
		
		filter = filter.concat(filterFile != null ? File.getContent(filterFile).replace("\r\n", "\n").replace("\r", "\n").split("\n") : []);
		
		mapper = mapper.copy();
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
		
		new codegen.Processor(generator, applyNatives, filter, mapper, true, includePrivate, requireNodeModule);
	}
	
	static function preserveOverloads() : Void
	{
		var dirsToExclude = platforms.filter(p -> !Context.defined(p));
		
		var tempDir = Path.removeTrailingSlashes(Sys.getEnv("temp")).replace("\\", "/");
		tempDir += "/CodeGen_" + Math.round(Sys.time() * 1000) + "_"  + Std.random(10000);
		
		var processedFiles = new Map<String, Bool>();
		for (classPath in Context.getClassPath())
		{
			classPath = Path.removeTrailingSlashes(classPath).replace("\\", "/");
			if (classPath != "")
			{
				preserveOverloadsProcessDir(classPath, "", processedFiles, tempDir, dirsToExclude);
			}
		}
		
		if (FileSystem.exists(tempDir))
		{
			haxe.macro.Compiler.addClassPath(tempDir);
			Context.onGenerate(_ -> deleteDirectory(tempDir));
		}
	}
	
	static function preserveOverloadsProcessDir(classPath:String, relDirPath:String, processedFiles:Map<String, Bool>, tempDir:String, dirsToExclude:Array<String>) : Void
	{
		var baseDir = classPath + (relDirPath != "" ? "/" + relDirPath : "");
		
		if (!FileSystem.exists(baseDir)) return;
		
		for (file in FileSystem.readDirectory(baseDir))
		{
			var path = (relDirPath != "" ? relDirPath + "/" : "") + file;
			
			if (dirsToExclude.indexOf(path) >= 0) continue;
			
			if (FileSystem.isDirectory(classPath + "/" + path))
			{
				preserveOverloadsProcessDir(classPath, path, processedFiles, tempDir, dirsToExclude);
			}
			else
			{
				if (Path.extension(path) == "hx" && !processedFiles.exists(path))
				{
					processedFiles.set(path, true);
					var text = File.getContent(classPath + "/" + path);
					var newText = new StringBuf();
					var n : Int;
					while ((n=text.indexOf("@:overload")) >= 0)
					{
						newText.add(text.substring(0, n + "@:overload".length));
						text = text.substring(n + "@:overload".length);
						while (text.charAt(0) == " " || text.charAt(0) == "\t")
						{
							newText.add(text.charAt(0));
							text = text.substring(1);
						}
						newText.add("(");
						text = text.substring(1);
						var finish = findClosedBracket(text);
						newText.add(text.substring(0, finish));
						newText.add(" @:real_overload(");
						newText.add(text.substring(0, finish));
						text = text.substring(finish);
					}
					newText.add(text);
					
					var newTextStr = newText.toString();
					if (newTextStr != text)
					{
						var destDir = tempDir + "/" + Path.directory(path);
						if (destDir != "" && !FileSystem.exists(destDir))
						{
							FileSystem.createDirectory(destDir);
						}
						File.saveContent(tempDir + "/" + path, newTextStr);
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
