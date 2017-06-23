import p.TestEnum;

class Run {
	static function main() {
		var likeVarExtracted = extractParameter(TestEnum.LikeVar);
		if (likeVarExtracted != -1) {
			throw 'LikeVar should extract to -1, got ${likeVarExtracted}';
		}

		var likeFuncExtracted = extractParameter(TestEnum.LikeFunc(34));
		if (likeFuncExtracted != 34) {
			throw 'LikeFunc should extract to 34, got ${likeFuncExtracted}';
		}
	}

	static function extractParameter(x) {
		return switch (x) {
			case TestEnum.LikeVar: -1;
			case TestEnum.LikeFunc(a): a;
			case TestEnum.Larry: -2;
		}
	}
}
