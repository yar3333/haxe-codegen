# codegen #

A macro tool to generate codes (haxe and none-haxe) from existing haxe source codes.

Useful if you split your project into several separate-compiled parts and you want to have common api (extern classes).

### Usage ###
Compile your project with '-lib codegen' and '--macro "CodeGen.**METHOD**(outPath,?topLevelPackage,?filterFile,?mapperFile)"'
where **METHOD** can be:

 * **haxeExtern** - generate haxe extern classes like haxe compiler '--gen-hx-classes' option;
 * **typescriptExtern** - generate typescript extern classes.

Other arguments detail:

 * outPath - path to output directory (for **haxeExtern**) or output file (for **typescriptExtern**);
 * topLevelPackage - a simple way to filter generated types;
 * filterFile - path to file with strings prefixed with "+" to include or "-" to exclude specified package/type (one per line);
 * mapperFile - path to file with strings in 'FromType => ToType' format (use to map types).

Private and marked with @noapi meta types/fields are ignored.
 
Example:
```
#!bash
haxe -lib mylib -cp src -main Main -js out.js --no-output -lib codegen --macro "CodeGen.haxeExtern('hxclasses','myproj.filter','myproj.mapper')" 
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