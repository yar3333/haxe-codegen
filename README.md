# codegen #

A macro tool to generate haxe externs and typescript definitions from existing haxe source code.

Useful if you want to split your project into several separate-compiled parts and you want to have common api (extern classes).

### Usage ###
Compile your haxe project with `-lib codegen` and one of the generation macro:

```shell
# generate haxe extern classes:
--macro CodeGen.haxeExtern(?outPath,?nodeModule,?filterFile,?mapperFile)

# generate typescript extern classes:
--macro CodeGen.typescriptExtern(?outPath,?filterFile,?mapperFile)
```
 
Arguments details:

 * outPath - path to output directory (for **haxeExtern**) or output file (for **typescriptExtern**);
 * nodeModule - used to generate `@:jsRequire` meta for exposed classes (for **haxeExtern**);
 * filterFile - path to a text file with lines prefixed with "+" to include or "-" to exclude specified package/type (one per line);
 * mapperFile - path to a text file with lines in 'FromType => ToType' format (use to map types).

### Example build.hxml ###
```bash
--library mylib 
--classpath src
--main Main
--js dummy.js
--library codegen
--macro CodeGen.haxeExtern('mynpmmodule','mypackA.mypackB', 'out')
```
**Filter** file example:
```bash
+mypack
# comment
-mypack.ClassToExclude
```
**Mapper** file example:
```bash
mypack.MyTypeA => mypack.MyType1
# comment
mypack.MyTypeB => mypack.MyType2

```

### Additional options ###
By default CodeGen produce externs for types included for compilation and marked with `@:expose` meta.
You can use `@:noapi` to force type/field excluding.
To customize generation process, use next compiler options before `CodeGen.haxeExtern` / `CodeGen.typescriptExtern`:

```shell
# use to include private class members into output
--macro CodeGen.includePrivateMembers()

# add @:expose for all classes inside specified package and subpackages
--macro CodeGen.exposeToRoot('mypack')

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

# copy specified module to output as is (for typescript ignored)
--macro CodeGen.copyAfterGeneration("mypack.MyClass")
```
