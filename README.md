# extgen #

A macro tool to generate externals from existing haxe source codes.

### Usage ###
Compile your project with "-lib extgen" and "--macro ExtGen.generate(generatorName,outDir,?topLevelPackage,?include,?exclude)"
Private and marked with @noapi meta types/fields ignored.

 * generatorName - one of the next: 'haxe-extern' (generate haxe extern classes like haxe compiler '--gen-hx-classes' option);
 * outDir - path to output directory;
 * topLevelPackage - help you filter generated types;
 * include - regex (with 'regex:' prefix) or path to file contains packages/modules to include (one per line);
 * exclude - regex (with 'regex:' prefix) or path to file contains packages/modules to exclude (one per line).

 
Example:
```
#!bash
haxe -lib mylib -cp src -main Main -js out.js --no-output -lib extgen --macro "ExtGen.generate('haxe-extern','hxclasses')" 
```
