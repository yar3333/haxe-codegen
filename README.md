# extgen #

A macro tool to generate externals from existing haxe source codes.

### Usage ###
Compile your project with "-lib extgen" and "--macro extgen.Macro.generateHaxeExternals('path_to_output_directory')":
```
#!bash
haxe -lib mylib -cp src -main Main -js out.js --no-output -lib extgen --macro "extgen.Macro.generateHaxeExternals('externs')" 
```
