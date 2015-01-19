# extgen #

A macro tool to generate externals (haxe and none-haxe) from existing haxe source codes.

Useful if you want to split your project to several separate-compiled parts
and you want to haxe api (extern classes) for your code parts commmunication.

### Usage ###
Compile your project with "-lib extgen" and "--macro ExtGen.generate(generatorName,outPath,?topLevelPackage,?filterFile)"

 * generatorName - one of the next:
	 * 'haxe-extern' (generate haxe extern classes like haxe compiler '--gen-hx-classes' option);
	 * 'typescript-extern' (generate typescript extern classes);
 * outPath - path to output directory (for 'haxe-extern') or output file (for 'typescript-extern');
 * topLevelPackage - a simple way to filter generated types;
 * filterFile - path to file with strings prefixed with "+" to include or "-" to exclude specified package/type (one per line).

Private and marked with @noapi meta types/fields are ignored.
 
Example:
```
#!bash
haxe -lib mylib -cp src -main Main -js out.js --no-output -lib extgen --macro "ExtGen.generate('haxe-extern','hxclasses','myproj.filter')" 

# myproj.filter file content:
+mypack
# comment
-mypack.ClassToExclude
```
