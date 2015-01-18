# extgen #

A macro tool to generate externals (haxe and none-haxe) from existing haxe source codes.

Useful if you want to split your project to several separate-compiled parts
and you want to haxe api (extern classes) for your code parts commmunication.

### Usage ###
Compile your project with "-lib extgen" and "--macro ExtGen.generate(generatorName,outPath,?topLevelPackage,?include,?exclude)"

 * generatorName - one of the next:
	 * 'haxe-extern' (generate haxe extern classes like haxe compiler '--gen-hx-classes' option);
	 * 'typescript-extern' (generate typescript extern classes);
 * outPath - path to output directory (for 'haxe-extern') or output file (for 'typescript-extern');
 * topLevelPackage - help you filter generated types;
 * include - regex (with 'regex:' prefix) or path to file contains packages/modules to include (one per line);
 * exclude - regex (with 'regex:' prefix) or path to file contains packages/modules to exclude (one per line).

Private and marked with @noapi meta types/fields ignored.
 
Example:
```
#!bash
haxe -lib mylib -cp src -main Main -js out.js --no-output -lib extgen --macro "ExtGen.generate('haxe-extern','hxclasses')" 
```
