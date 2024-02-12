export namespace pack_a
{
	export class TestClassC
	{
		constructor();
		linkA : pack_a.TestClassC;
		linkB : RootClass;
	}
	
	export enum TestEnum
	{
		LikeVar,
		LikeFunc(a:number)
	}
	
	type TestEnumAbstract = string;
	
	export class TestExtern
	{
		static play(src:string, options:number) : string;
		static play(src:string, interrupt?:string, delay?:number, offset?:number, loop?:number, volume?:number, pan?:number, startTime?:number, duration?:number) : string;
	}
	
	export class TestGeneric<MyT>
	{
		protected myFunc(obj:MyT) : void;
	}
	
	export class TestGeneric extends pack_a.TestGeneric.TestBaseGeneric<pack_a.TestClassC>
	{
	
	}
	
	export class TestProperty
	{
		get_myProp() : any;
		set_myProp(v:any) : any;
	}
	
	type TestTypedef =
	{
		a : number;
		b : string;
		c : pack_a.TestClassC;
	}
}

export namespace RootClass
{
	type MySubTypeInRootClass =
	{ }
}

export class RootClass
{
	constructor();
}