// Run this with haxe -x Run

using Lambda;
using StringTools;

class Run {
	static var targets = [
		new JsTarget(),
		new NekoTarget(),
		new CsTarget(),
	];

	static function main() {
		var passed = [];
		var failed = [];
		var paths = if (Sys.args().empty()) sys.FileSystem.readDirectory('.') else Sys.args();
		for (path in paths) {
			if (!sys.FileSystem.isDirectory(path)) {
				continue;
			}
			trace('Running ${path}');
			try {
				runConstruct(path);
				passed.push(path);
				trace('PASS ${path}');
			} catch (ex:Dynamic) {
				failed.push(path);
				trace(ex);
				trace('FAIL ${path}');
			}
		}
		trace('');
		trace('Passed: ${passed.length}');
		trace('Failed: ${failed.length}');
		if (!failed.empty()) {
			trace('');
			trace('The following tests failed:');
			for (path in failed) {
				trace(path);
			}
		}
		Sys.exit(if (failed.empty()) 0 else 1);
	}

	static function runConstruct(path) {
		for (target in targets) {
			target.run(path);
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

	public function run(path) {
		// Remove any artifacts from prior run.
		var binPaths = [for (relPath in ['api', 'consumer']) haxe.io.Path.join([path, relPath, 'bin'])];
		for (path in binPaths) {
			Util.rimraf(path);
		}

		// Load list of api modules.
		var apiModules = Util.readLines(haxe.io.Path.join([path, 'api', 'MODULES']));

		// Compile.
		var apiCompileArgs = [
			'-cp',
			haxe.io.Path.join([path, 'api']),
		].concat(apiModules).concat([
			'-${name}',
			getApiOutputPath(path),
		]);
		runCommand('haxe', apiCompileArgs);

		// codegen
		var filterPath = haxe.io.Path.join([path, 'api', 'bin', 'codegen.filter']);

		// Generate codegen.filter. Use user-provided one in api folder but
		// fallback to generating from MODULES (works for most cases).
		var codegenFilterOverridePath = haxe.io.Path.join([path, 'api', 'codegen.filter']);
		var codegenFilterLines;
		if (sys.FileSystem.exists(codegenFilterOverridePath)) {
			codegenFilterLines = Util.readLines(codegenFilterOverridePath);
		} else {
			codegenFilterLines = [for (module in apiModules) '+${module}'];
		}
		Util.writeLines(filterPath, codegenFilterLines);

		var apiCodegenArgs = apiCompileArgs.concat([
			'-cp',
			haxe.io.Path.join(['..', '..', 'library']),
			'--macro',
			'CodeGen.haxeExtern(\'${getApiExternOutputPath(path)}\',\'\',\'${filterPath}\')',
		]);
		runCommand('haxe', apiCodegenArgs);

		// Compile consumer
		var consumerCompileArgs = getConsumerCompileArgs(path);
		runCommand('haxe', consumerCompileArgs);

		runConsumer(path);

		// Process any expected failures
		var expectedFailuresPath = haxe.io.Path.join([path, 'consumer', 'EXPECTED_FAILURES']);
		if (sys.FileSystem.exists(expectedFailuresPath)) {
			for (line in Util.readLines(expectedFailuresPath)) {
				var lineParts = ~/^([^:]+):(.*)/;
				if (lineParts.match(line)) {
					var conditionalDefine = lineParts.matched(1);
					var expectedError = lineParts.matched(2);

					var expectedFailureCompileArgs = consumerCompileArgs.concat([
						'-D',
						conditionalDefine,
					]);
					trace('Running haxe ${[for (arg in expectedFailureCompileArgs) '"${arg}"'].join(' ')}');
					var expectedFailureProcess = new sys.io.Process('haxe', expectedFailureCompileArgs);
					var messages = [];
					var stderrDone = false;
					var stdoutDone = false;
					while (!stderrDone || !stdoutDone) {
						try {
							messages.push(expectedFailureProcess.stdout.readLine());
						} catch (ex:haxe.io.Eof) {
							stdoutDone = true;
						}
						try {
							messages.push(expectedFailureProcess.stderr.readLine());
						} catch (ex:haxe.io.Eof) {
							stderrDone = true;
						}
					}
					var expectedFailureExitCode = expectedFailureProcess.exitCode();
					if (expectedFailureExitCode == 0) {
						throw 'Expected failure failed to fail: haxe exited with ${expectedFailureExitCode}';
					}
					if (messages.filter(function (message) return message.indexOf(expectedError) != -1).empty()) {
						throw 'Expected failure: “${expectedError}”. Instead got the following messages:\r\n${messages.join('\r\n')}';
					}
				}
			}
		}
	}

	/**
	 Run from within the consumer’s bin directory.
	 **/
	function runConsumer(path) {
		trace('Target ${name} does not support running the consumer yet, skipping.');
	}

	function getApiOutputPath(path) {
		return haxe.io.Path.join([path, 'api', 'bin', 'api.${name}']);
	}

	function getApiExternOutputPath(path) {
		return haxe.io.Path.join([path, 'api', 'bin', 'externs']);
	}

	function getConsumerOutputPath(path) {
		return haxe.io.Path.join([path, 'consumer', 'bin', 'Run.${name}']);
	}

	function getConsumerCompileArgs(path) {
		return [
			'-cp',
			getApiExternOutputPath(path),
			'-cp',
			haxe.io.Path.join([path, 'consumer']),
			'-main',
			'Run',
			'-${name}',
			getConsumerOutputPath(path),
		];
	}
}

private class JsTarget extends Target {
	public function new() {
		super('js');
	}

	override function runConsumer(path) {
		// Concatenate the files.
		var outputPath = '${getConsumerOutputPath(path)}.concatenated.js';
		var output = sys.io.File.write(outputPath);
		// To get haxe to write exports to the global object, set exports=global:
		output.writeString('exports = global;//Least coding way to get consumer module to see other module’s code\n');
		for (inputPath in [getApiOutputPath(path), getConsumerOutputPath(path)]) {
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

	function getApiAssemblyOutputPath(path) {
		return haxe.io.Path.join([getApiOutputPath(path), 'bin', 'api.cs.dll']);
	}

	function getConsumerAssemblyOutputPath(path) {
		return haxe.io.Path.join([getConsumerOutputPath(path), 'bin', 'Run.exe']);
	}

	override function getConsumerCompileArgs(path) {
		return [
			'-net-lib',
			getApiAssemblyOutputPath(path),
		].concat(super.getConsumerCompileArgs(path));
	}

	override function runConsumer(path) {
		// Try to use mono if it is available to support non-Windows
		// platforms.
		var assembly = getConsumerAssemblyOutputPath(path);
		if (useMono) {
			runCommand('mono', [assembly]);
		} else {
			runCommand(assembly);
		}
	}
}
