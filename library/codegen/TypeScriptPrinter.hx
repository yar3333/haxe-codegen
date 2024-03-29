package codegen;

import haxe.macro.Expr;
using Lambda;
using StringTools;

class TypeScriptPrinter {
	var tabs:String;
	var tabString:String;

	public function new(?tabString = "\t") {
		tabs = "";
		this.tabString = tabString;
	}

	public function printUnop(op:Unop) return switch(op) {
		case OpIncrement: "++";
		case OpDecrement: "--";
		case OpNot: "!";
		case OpNeg: "-";
		case OpNegBits: "~";
		case OpSpread: "...";
	}

	public function printBinop(op:Binop) return switch(op) {
		case OpAdd: "+";
		case OpMult: "*";
		case OpDiv: "/";
		case OpSub: "-";
		case OpAssign: "=";
		case OpEq: "==";
		case OpNotEq: "!=";
		case OpGt: ">";
		case OpGte: ">=";
		case OpLt: "<";
		case OpLte: "<=";
		case OpAnd: "&";
		case OpOr: "|";
		case OpXor: "^";
		case OpBoolAnd: "&&";
		case OpBoolOr: "||";
		case OpShl: "<<";
		case OpShr: ">>";
		case OpUShr: ">>>";
		case OpMod: "%";
		case OpInterval: "...";
		case OpArrow: "=>";
		case OpAssignOp(op):
			printBinop(op)
			+ "=";
        case OpIn: "in";
        case OpNullCoal: "??";
	}
	public function printString(s:String) {
		return '"' + s.split("\n").join("\\n").split("\t").join("\\t").split("'").join("\\'").split('"').join("\\\"") #if sys .split("\x00").join("\\x00") #end + '"';
	}
	public function printConstant(c:Constant) return switch(c) {
		case CString(s): printString(s);
		case CIdent(s),
			CInt(s),
			CFloat(s):
				s;
		case CRegexp(s,opt): '~/$s/$opt';
	}

	public function printTypeParam(param:TypeParam) return switch(param) {
		case TPType(ct): printComplexType(ct);
		case TPExpr(e): printExpr(e);
	}

	public function printTypePath(tp:TypePath)
	{
		if (tp.pack.length == 0 && tp.name == "Array" && tp.sub == null && tp.params.length==1)
		{
			return printTypeParam(tp.params[0]) + "[]";
		}
		
		return convertType
		(
			(tp.pack.length > 0 ? tp.pack.join(".") + "." : "")
			+ tp.name
			+ (tp.sub != null ? '.${tp.sub}' : "")
			+ (tp.params.length > 0 ? "<" + tp.params.map(printTypeParam).join(", ") + ">" : "")
		);
	}

	// TODO: check if this can cause loops
	public function printComplexType(ct:ComplexType) return switch(ct) {
		case TPath(tp): printTypePath(tp);
		case TFunction(args, ret):
			"(" + (args.length > 0 ? args.mapi(function(i, arg) return "arg" + (args.length > 1 ? Std.string(i) : "") + ":" + printComplexType(arg)).join(", ") : "") + ") => " + printComplexType(ret);
		case TAnonymous(fields): "{ " + fields.map(x -> printField(x) + "; ").join("") + "}";
		case TParent(ct): "(" + printComplexType(ct) + ")";
		case TOptional(ct): "?" + printComplexType(ct);
		case TExtend(tpl, fields): '{> ${tpl.map(printTypePath).join(" >, ")}, ${fields.map(printField).join(", ")} }';
        case TIntersection(tl): "" + [for (t in tl) printComplexType(t)].join(" & ") + "";
        case TNamed(n, t): printComplexType(t);
	}

	public function printMetadatas(meta:Array<MetadataEntry>, joinStr:String, field:Field)
	{
		var m = meta != null ? meta.map(printMetadata.bind(_, field)).filter(function(m) return m != "") : [];
		return m.length > 0 ? m.join(joinStr) + joinStr : "";
	}

	public function printMetadata(meta:MetadataEntry, field:Field)
	{
		if (meta.name == ":overload")
		{
			return
				printAccesses(field.access)
			  + switch (field.kind)
				{
					case FFun(func):
						var z = printExpr(meta.params[0]);
                        z = z.substr(z.indexOf("("));
						while (StringTools.endsWith(z, "}")) z = z.substring(0, z.length - 1);
						while (StringTools.endsWith(z, " ")) z = z.substring(0, z.length - 1);
						while (StringTools.endsWith(z, "{")) z = z.substring(0, z.length - 1);
						while (StringTools.endsWith(z, " ")) z = z.substring(0, z.length - 1);
						field.name + z + ";";
					case _: "";
				};
		}
		return "";
	}

	public function printAccesses(accesses:Array<Access>)
	{
		if (accesses == null) return "";
		var items = accesses.map(printAccess).filter(function(a) return a != null && a != "");
		if (items.length == 0) return "";
		return items.join(" ") + " ";
	}

	public function printAccess(access:Access) return switch(access) {
		case AStatic: "static";
		case APublic: "";
		case APrivate: "protected";
		case AOverride: null;
		case AInline: "inline";
		case ADynamic: "dynamic";
		case AMacro: "macro";
		case AAbstract: "abstract";
		case AExtern: "extern";
		case AFinal: "final";
		case AOverload: "overload";
	}

	public function printField(field:Field) return
		printDoc(field.doc)
		+ printMetadatas(field.meta, "\n" + tabs, field)
		+ printAccesses(field.access)
		+ switch(field.kind) {
		  case FVar(t, eo): field.name + opt(t, printComplexType, " : ") + opt(eo, printExpr, " = ");
		  case FProp(get, set, t, eo): field.name + opt(t, printComplexType, " : ") + opt(eo, printExpr, " = ");
		  case FFun(func): field.name + printFunction(func);
		}


	public function printTypeParamDecl(tpd:TypeParamDecl) return
		tpd.name
		+ (tpd.params != null && tpd.params.length > 0 ? "<" + tpd.params.map(printTypeParamDecl).join(", ") + ">" : "")
		+ (
			tpd.constraints != null && tpd.constraints.length > 0
				? ":" + (tpd.constraints.length > 1 ? "(" : "") + tpd.constraints.map(printComplexType).join(", ") + (tpd.constraints.length > 1 ? "(" : "")
				: ""
		  );

	public function printFunctionArg(arg:FunctionArg) return
		  arg.name
		+ (arg.opt ? "?" : "")
		+ opt(arg.type, printComplexType, ":")
		+ opt(arg.value, printExpr, " = ");

	public function printFunction(func:Function) return
		(func.params.length > 0 ? "<" + func.params.map(printTypeParamDecl).join(", ") + ">" : "")
		+ "(" + func.args.map(printFunctionArg).join(", ") + ")"
		+ opt(func.ret, printComplexType, " : ")
		+ opt(func.expr, printExpr, " ");

	public function printVar(v:Var) return
		v.name
		+ opt(v.type, printComplexType, ":")
		+ opt(v.expr, printExpr, " = ");


	public function printExpr(e:Expr) 
    {
        if (e == null) return "#NULL";
        
        return switch(e.expr) {
	        case EConst(c): printConstant(c);
            case EArray(e1, e2): '${printExpr(e1)}[${printExpr(e2)}]';
            case EBinop(op, e1, e2): '${printExpr(e1)} ${printBinop(op)} ${printExpr(e2)}';
            case EField(e1, n): '${printExpr(e1)}.$n';
            case EParenthesis(e1): '(${printExpr(e1)})';
            case EObjectDecl(fl):
                "{ " + fl.map(function(fld) return '${fld.field} : ${printExpr(fld.expr)}').join(", ") + " }";
            case EArrayDecl(el): '[${printExprs(el, ", ")}]';
            case ECall(e1, el): '${printExpr(e1)}(${printExprs(el,", ")})';
            case ENew(tp, el): 'new ${printTypePath(tp)}(${printExprs(el,", ")})';
            case EUnop(op, true, e1): printExpr(e1) + printUnop(op);
            case EUnop(op, false, e1): printUnop(op) + printExpr(e1);
            case EFunction(no, func) if (no != null): 'function $no' + printFunction(func);
            case EFunction(_, func): "function" +printFunction(func);
            case EVars(vl): "var " +vl.map(printVar).join(", ");
            case EBlock([]): '{ }';
            case EBlock(el):
                var old = tabs;
                tabs += tabString;
                var s = '{\n$tabs' + printExprs(el, ';\n$tabs');
                tabs = old;
                s + ';\n$tabs}';
            case EFor(e1, e2): 'for (${printExpr(e1)}) ${printExpr(e2)}';
            case EIf(econd, eif, null): 'if (${printExpr(econd)}) ${printExpr(eif)}';
            case EIf(econd, eif, eelse): 'if (${printExpr(econd)}) ${printExpr(eif)} else ${printExpr(eelse)}';
            case EWhile(econd, e1, true): 'while (${printExpr(econd)}) ${printExpr(e1)}';
            case EWhile(econd, e1, false): 'do ${printExpr(e1)} while (${printExpr(econd)})';
            case ESwitch(e1, cl, edef):
                var old = tabs;
                tabs += tabString;
                var s = 'switch ${printExpr(e1)} {\n$tabs' +
                    cl.map(function(c)
                        return 'case ${printExprs(c.values, ", ")}'
                            + (c.guard != null ? ' if (${printExpr(c.guard)}):' : ":")
                            + (c.expr != null ? (opt(c.expr, printExpr)) + ";" : ""))
                    .join('\n$tabs');
                if (edef != null)
                    s += '\n${tabs}default:' + (edef.expr == null ? "" : printExpr(edef) + ";");
                tabs = old;
                s + '\n$tabs}';
            case ETry(e1, cl):
                'try ${printExpr(e1)}'
                + cl.map(function(c) return ' catch(${c.name}:${printComplexType(c.type)}) ${printExpr(c.expr)}').join("");
            case EReturn(eo): "return" + opt(eo, printExpr, " ");
            case EBreak: "break";
            case EContinue: "continue";
            case EUntyped(e1): "untyped " +printExpr(e1);
            case EThrow(e1): "throw " +printExpr(e1);
            case ECast(e1, cto) if (cto != null): 'cast(${printExpr(e1)}, ${printComplexType(cto)})';
            case ECast(e1, _): "cast " +printExpr(e1);
            case EDisplay(e1, _): '#DISPLAY(${printExpr(e1)})';
            case ETernary(econd, eif, eelse): '${printExpr(econd)} ? ${printExpr(eif)} : ${printExpr(eelse)}';
            case ECheckType(e1, ct): '(${printExpr(e1)} : ${printComplexType(ct)})';
            case EMeta(meta, e1): printMetadata(meta, null) + " " +printExpr(e1);
            case EIs(e, t): printExpr(e) + " is " + printComplexType(t);
        }
    }

	public function printExprs(el:Array<Expr>, sep:String) {
		return el.map(printExpr).join(sep);
	}

	function printExtension(tpl:Array<TypePath>, fields: Array<Field>) {
		return '{\n$tabs>' + tpl.map(printTypePath).join(',\n$tabs>') + ","
		    + (fields.length > 0 ? ('\n$tabs' + fields.map(printField).join(';\n$tabs') + ";\n}") : ("\n}"));
	}

	function printStructure(fields:Array<Field>) {
		return fields.length == 0 ? "{ }" :
			'{\n$tabs' + fields.map(printField).join(';\n$tabs') + ";\n}";
	}

	public function printTypeDefinition(t:TypeDefinition, printPackage = true):String {
		var old = tabs;
		tabs = tabString;

        var str: String;

        if (t == null) str = "#NULL";
        else str = 
			(printPackage && t.pack.length > 0 && t.pack[0] != "" ? "package " + t.pack.join(".") + ";\n" : "") +
			printMetadatas(t.meta, " ", null) + (t.isExtern ? "export " : "") + switch (t.kind) {
				case TDEnum:
					"enum " + t.name + (t.params.length > 0 ? "<" + t.params.map(printTypeParamDecl).join(", ") + ">" : "") + "\n{\n"
					+ t.fields.map(function (field) return
						tabs + printDoc(field.doc)
						+ printMetadatas(field.meta, " ", field)
						+ (switch(field.kind) {
							case FVar(t, _): field.name + opt(t, printComplexType, ":");
							case FProp(_, _, _, _): throw "FProp is invalid for TDEnum.";
							case FFun(func): field.name + printFunction(func);
						})
					).join(",\n")
					+ "\n}";
				case TDStructure:
					"interface " + t.name + (t.params.length > 0 ? "<" + t.params.map(printTypeParamDecl).join(", ") + ">" : "") + "\n{\n"
					+ t.fields.map(f -> tabs + printField(f) + ";").join("\n")
					+ "\n}";
				case TDClass(superClass, interfaces, isInterface):
					(isInterface ? "interface " : "class ") + t.name + (t.params.length > 0 ? "<" + t.params.map(printTypeParamDecl).join(", ") + ">" : "")
					+ (superClass != null ? " extends " + printTypePath(superClass) : "")
					+ (interfaces != null && interfaces.length>0 ? (isInterface ? [for (tp in interfaces) " extends " + printTypePath(tp)].join("") : " implements " + interfaces.map(printTypePath).join(", ")) : "")
					+ "\n{\n"
					+ [for (f in t.fields) {
						tabs + printField(f) + switch(f.kind) {
							case FVar(_, _), FProp(_, _, _, _): ";";
							case FFun(func) if (func.expr == null): ";";
							case _: "";
						};
					}].join("\n")
					+ "\n}";
				case TDAlias(ct):
					"type " + t.name + (t.params.length > 0 ? "<" + t.params.map(printTypeParamDecl).join(", ") + ">" : "") + " ="
					+ switch(ct) {
						case TExtend(tpl, fields): "\n" + printExtension(tpl, fields) + ";";
						case TAnonymous(fields): "\n" + printStructure(fields);
						case _: " " + printComplexType(ct) + ";";
					};
				case TDAbstract(tthis, flags, from, to):
					"abstract " + t.name
					+ (t.params.length > 0 ? "<" + t.params.map(printTypeParamDecl).join(", ") + ">" : "")
					+ (tthis == null ? "" : "(" + printComplexType(tthis) + ")")
					+ (from == null ? "" : [for (f in from) " from " + printComplexType(f)].join(""))
					+ (to == null ? "" : [for (t in to) " to " + printComplexType(t)].join(""))
					+ "\n{\n"
					+ [for (f in t.fields) {
						tabs + printField(f) + switch(f.kind) {
							case FVar(_, _), FProp(_, _, _, _): ";";
							case FFun(func) if (func.expr == null): ";";
							case _: "";
						};
					}].join("\n")
					+ "\n}";
                case TDField(kind, access): printField({ access: access, pos: t.pos, kind: kind, name: t.name });
			}

		tabs = old;
		return str;
	}

	function opt<T>(v:T, f:T->String, prefix = "") return v == null ? "" : (prefix + f(v));
	
	function printDoc(doc:String) : String
	{
		return doc != null && doc != "" 
			? "/**\n" + tabs + " " + StringTools.trim(doc).split("\n").map(StringTools.trim).join("\n" + tabs + " ") + "\n" + tabs + " */\n" + tabs
			: "";
	}
	
	function convertType(s:String) : String
	{
		switch (s)
		{
			case "Void": return "void";
			case "Int", "Float": return "number";
			case "String": return "string";
			case "Bool": return "boolean";
			case "Dynamic": return "any";
			case _: return s;
		}
	}
}
