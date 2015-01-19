# codegen #

A macro tool to generate codes (haxe and none-haxe) from existing haxe source codes.

Useful if you want to split your project to several separate-compiled parts
and you want to haxe api (extern classes) for your code parts commmunication.

### Usage ###
Compile your project with "-lib codegen" and "--macro CodeGen.generate(generatorName,outPath,?topLevelPackage,?filterFile,?mapperFile)"

 * generatorName - one of the next:
	 * **haxe-extern** - generate haxe extern classes like haxe compiler '--gen-hx-classes' option;
	 * **typescript-extern** - generate typescript extern classes;
 * outPath - path to output directory (for **haxe-extern**) or output file (for **typescript-extern**);
 * topLevelPackage - a simple way to filter generated types;
 * filterFile - path to file with strings prefixed with "+" to include or "-" to exclude specified package/type (one per line);
 * mapperFile - path to file with strings in 'FromType => ToType' format (use to map types).

Private and marked with @noapi meta types/fields are ignored.
 
Example:
```
#!bash
haxe -lib mylib -cp src -main Main -js out.js --no-output -lib codegen --macro "CodeGen.generate('haxe-extern','hxclasses','myproj.filter','myproj.mapper')" 
```

**myproj.filter** file example:
```
#!bash
+mypack
# comment
-mypack.ClassToExclude
```

**myproj.mapper** file example:
```
#!bash
mypack.MyTypeA => mypack.MyType1
# comment
mypack.MyTypeB => mypack.MyType2

```