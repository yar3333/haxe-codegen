# codegen #

A macro tool to generate codes (haxe and none-haxe) from existing haxe source codes.

Useful if you want to split your project into several separate-compiled parts and you want to have common api (extern classes).

### Usage ###
Compile your project with `-lib codegen` and one of the generation macro:

 * `--macro "CodeGen.haxeExtern(outPath,?applyNatives,?topLevelPackage,?filterFile,?mapperFile,?includePrivate,?requireNodeModule)"` - generate haxe extern classes like haxe compiler '--gen-hx-classes' option;
 * `--macro "CodeGen.typescriptExtern(outPath,?topLevelPackage,?filterFile,?mapperFile,?includePrivate)"` - generate typescript extern classes.

Other arguments details:

 * outPath - path to output directory (for **haxeExtern**) or output file (for **typescriptExtern**);
 * applyNatives - are resolve `@:native` metas (default is `false` for **haxeExtern** and always `true` for **typescriptExtern**);
 * topLevelPackage - a simple way to filter generated types (specify `''` to not exclude any packages);
 * filterFile - path to a text file with lines prefixed with "+" to include or "-" to exclude specified package/type (one per line);
 * mapperFile - path to a text file with lines in 'FromType => ToType' format (use to map types);
 * includePrivate - include private class members into output (default is `false`);
 * requireNodeModule - module name to generate `@:jsRequire` meta for classes.

You can mark types/fields with `@:noapi` meta to exclude them from output.
 
### Example ###
```bash
haxe -lib mylib -cp src -main Main -js dummy.js -lib codegen --macro "CodeGen.haxeExtern('hxclasses','','myproj.filter','myproj.mapper')" 
```

**myproj.filter** file example:
```bash
+mypack
# comment
-mypack.ClassToExclude
```

**myproj.mapper** file example:
```bash
mypack.MyTypeA => mypack.MyType1
# comment
mypack.MyTypeB => mypack.MyType2

```