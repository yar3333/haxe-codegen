# extgen #

A macro tool to generate externals from existing haxe source codes.

### Usage ###
Compile your project with "-lib extgen" and "--macro ExtGen.generate('generator_name','path_to_output_directory')":
```
#!bash
haxe -lib mylib -cp src -main Main -js out.js --no-output -lib extgen --macro "ExtGen.generate('haxe-extern','hxclasses')" 
```

Supported generators:
 * haxe-extern - generate extern haxe classes (like '--gen-hx-classes' haxe compiler option).
