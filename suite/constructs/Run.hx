// Run this with haxe -x Run

class Run {
	static var targets = [
		new JsTarget(),
		new NekoTarget(),
		new CsTarget(),
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
				trace('PASS ${path}');
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

	function runCommand(command:String, ?args:Array<String>) {
		args = if (args == null) [] else args;

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
		var consumerCompileArgs = getConsumerCompileArgs();
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

	function getConsumerCompileArgs() {
		return [
			'-cp',
			getApiExternOutputPath(),
			'-cp',
			'consumer',
			'-main',
			'Run',
			'-${name}',
			getConsumerOutputPath(),
		];
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

/**
 Note that on compilation the Haxe CS target warns that we should use
 -D dll_import. Right now I’m thinking that the generated externs from
 codegen actually should provide the information we need, so that warning
 can safely be ignored.
 **/
private class CsTarget extends Target {
	// Use process to trap stderr/stdout
	var useMono = new sys.io.Process('mono --version').exitCode() == 0;

	public function new() {
		super('cs');
	}

	function getApiAssemblyOutputPath() {
		return '${getApiOutputPath()}/bin/api.cs.dll';
	}

	function getConsumerAssemblyOutputPath() {
		return '${getConsumerOutputPath()}/bin/Run.exe';
	}

	override function getConsumerCompileArgs() {
		return [
			'-net-lib',
			getApiAssemblyOutputPath(),
		].concat(super.getConsumerCompileArgs());
	}

	override function runConsumer() {
		// Try to use mono if it is available to support non-Windows
		// platforms.
		var assembly = getConsumerAssemblyOutputPath();
		if (useMono) {
			runCommand('mono', [assembly]);
		} else {
			runCommand(assembly);
		}
	}
}
