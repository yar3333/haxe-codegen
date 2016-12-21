// Run this with haxe -x Run

class Run {
	static var targets = [
		new JsTarget(),
	];

	static function main() {
		var ret = 0;
		for (path in sys.FileSystem.readDirectory('.')) {
			if (!sys.FileSystem.isDirectory(path)) {
				continue;
			}
			trace('descending to ${path}');
			Sys.setCwd(path);
			try {
				runConstruct();
			} catch (ex:Dynamic) {
				ret = 1;
				trace(ex);
				trace('FAIL ${path}');
			}
			Sys.setCwd('..');
		}
		Sys.exit(ret);
	}

	static function runConstruct() {
		for (target in targets) {
			target.run();
		}
	}
}

class Util {
	// Should probably use some external library instead
	public static function rimraf(path) {
		if (!sys.FileSystem.exists(path)) {
		} else if (sys.FileSystem.isDirectory(path)) {
			for (entry in sys.FileSystem.readDirectory(path)) {
				trace(entry);
				if (entry == '.' || entry == '..') {
					continue;
				}

				var entryPath = haxe.io.Path.join([path, entry]);
				rimraf(entryPath);
			}
			sys.FileSystem.deleteDirectory(path);
		} else {
			sys.FileSystem.deleteFile(path);
		}
	}

	public static function readLines(path) {
		var file = sys.io.File.read(path);
		var ret = [];
		try {
			while (true) {
				var line = file.readLine();
				ret.push(line);
			}
		} catch (ex:haxe.io.Eof) {
		}
		file.close();
		return ret;
	}

	public static function writeLines(path, lines:Iterable<String>) {
		var file = sys.io.File.write(path);
		for (line in lines) {
			file.writeString(line);
			file.writeString('\n');
		}
		file.close();
	}
}

private class Target {
	public var name(default, null):String;

	function new(name) {
		this.name = name;
	}

	function runCommand(command:String, args:Array<String>) {
		trace('Running ${command} ${[for (arg in args) '"${arg}"'].join(' ')}');
		if (Sys.command(command, args) != 0) {
			throw 'Command failed. CWD=${Sys.getCwd()}';
		}
	}

	public function run() {
		// Remove any artifacts from prior run.
		for (path in ['api/bin', 'consumer/bin']) {
			Util.rimraf(path);
		}

		// Load list of api modules.
		var apiModules = Util.readLines(haxe.io.Path.join(['api', 'MODULES']));

		// Compile.
		var apiCompileArgs = [
			'-cp',
			'api',
		].concat(apiModules).concat([
			'-${name}',
			getApiOutputPath(),
		]);
		runCommand('haxe', apiCompileArgs);

		// codegen
		var filterPath = haxe.io.Path.join(['api', 'bin', 'codegen.filter']);
		Util.writeLines(filterPath, [for (module in apiModules) '+${module}']);
		var apiCodegenArgs = apiCompileArgs.concat([
			'-cp',
			haxe.io.Path.join(['..', '..', '..', 'library']),
			'--macro',
			'CodeGen.haxeExtern(\'${getApiExternOutputPath()}\',\'\',\'${filterPath}\')',
		]);
		runCommand('haxe', apiCodegenArgs);

		// Compile consumer
		var consumerCompileArgs = [
			'-cp',
			getApiExternOutputPath(),
			'-cp',
			'consumer',
			'-main',
			'Run',
			'-${name}',
			getConsumerOutputPath(),
		];
		runCommand('haxe', consumerCompileArgs);

		runConsumer();
	}

	/**
	 Run from within the consumer’s bin directory.
	 **/
	function runConsumer() {
		trace('Target ${name} does not support running the consumer yet, skipping.');
	}

	function getApiOutputPath() {
		return haxe.io.Path.join(['api', 'bin', 'api.${name}']);
	}

	function getApiExternOutputPath() {
		return haxe.io.Path.join(['api', 'bin', 'externs']);
	}

	function getConsumerOutputPath() {
		return haxe.io.Path.join(['consumer', 'bin', 'Run.${name}']);
	}
}

private class JsTarget extends Target {
	public function new() {
		super('js');
	}

	override function runConsumer() {
		// Concatenate the files.
		var outputPath = '${getConsumerOutputPath()}.concatenated.js';
		var output = sys.io.File.write(outputPath);
		// To get haxe to write exports to the global object, set exports=global:
		output.writeString('exports = global;//Least coding way to get consumer module to see other module’s code\n');
		for (inputPath in [getApiOutputPath(), getConsumerOutputPath()]) {
			output.writeString('//BEGIN ${inputPath}\n');
			var input = sys.io.File.read(inputPath);
			output.writeInput(input);
			output.writeString('//END ${inputPath}\n');
			input.close();
		}
		output.close();

		// Run
		runCommand('node', [
			outputPath,
		]);
	}
}

private class NekoTarget extends Target {
	public function new() {
		super('neko');
	}
}
