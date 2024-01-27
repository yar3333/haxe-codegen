# codegen #

A macro tool to generate haxe externs and typescript definitions from existing haxe source code.

Useful if you want to split your project into several separate-compiled parts and you want to have common api (extern classes).

### Usage ###
Compile your haxe project with `-lib codegen` and one of the generation macro:

```shell
# generate haxe extern classes:
--macro CodeGen.haxeExtern(?requireNodeModule,?outPackage,?outPath,?filterFile,?mapperFile)

# generate typescript extern classes:
--macro CodeGen.typescriptExtern(?outPath,?filterFile,?mapperFile)
```
 
Arguments details:

 * requireNodeModule - module name to generate `@:jsRequire` meta (for **haxeExtern**);
 * outPackage - output package name to generate (for **haxeExtern**);
 * outPath - path to output directory (for **haxeExtern**) or output file (for **typescriptExtern**);
 * filterFile - path to a text file with lines prefixed with "+" to include or "-" to exclude specified package/type (one per line);
 * mapperFile - path to a text file with lines in 'FromType => ToType' format (use to map types).

### Example build.hxml ###
```bash
--library mylib 
--classpath src
--main Main
--js dummy.js
--library codegen
--macro CodeGen.haxeExtern('mynpmmodule','mypackA.mypackB','myRules.filter','myRules.mapper')
```
**myRules.filter** file example:
```bash
+mypack
# comment
-mypack.ClassToExclude
```
**myRules.mapper** file example:
```bash
mypack.MyTypeA => mypack.MyType1
# comment
mypack.MyTypeB => mypack.MyType2

```

### Additional options ###
By default CodeGen produce externs for types included for compilation and marked with `@:expose` meta.
You can use `@:noapi` to force type excluding if type in included package. Also `@:noapi` works for fields.

```shell
# use to include private class members into output
--macro CodeGen.includePrivateMembers()

# include myPackA and myPackB.MyClass into generation
--macro CodeGen.include('myPackA myPackB.MyClass')

# exclude myPackA and myPackB.MyClass from generation
--macro CodeGen.exclude('myPackA myPackB')

# map package myPackA to package myPackB in output
--macro CodeGen.map('myPackA','myPackB')

# map class myPackA.MyClassA to class myPackB.MyClassB in output
--macro CodeGen.map('myPackA.MyClassA','myPackB.MyClassB')

# cleanup: remove `@mymeta` from output (types)
--macro CodeGen.removeTypeMeta('mymeta')

# cleanup: remove `@mymeta` from output (fields)
--macro CodeGen.removeFieldMeta('mymeta')
```
