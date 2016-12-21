// Run this with haxe -x Run

class Run {
	static function main() {
		var ret = 0;
		for (path in sys.FileSystem.readDirectory('.')) {
			if (!sys.FileSystem.exists(haxe.io.Path.join([path, 'Run.hx']))) {
				continue;
			}
			trace('descending to ${path}');
			Sys.setCwd(path);
			var result = Sys.command('haxe -x Run');
			if (result != 0) {
				trace('FAIL ${path}');
				ret = result;
			}
			Sys.setCwd('..');
		}
		Sys.exit(ret);
	}
}
