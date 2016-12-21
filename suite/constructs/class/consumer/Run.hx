class Run {
	static function main() {
		var cat = new Cat();
		var meow = cat.meow();
		if (meow != 'meow') {
			throw 'Cat doesn’t meow properly: ${meow}';
		}

		cat = new SubCat();
		meow = cat.meow();
		if (meow != 'woof') {
			throw 'SubCat doesn’t meow properly: ${meow} (expecting woof)';
		}
	}
}

private class SubCat extends Cat {
	public override function meow() {
		return 'woof';
	}
}
