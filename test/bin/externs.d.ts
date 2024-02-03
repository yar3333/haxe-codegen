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
	
	export class TestExtern
	{
		static play(src:string, options:number) : string;
		static play(src:string, interrupt?:string, delay?:number, offset?:number, loop?:number, volume?:number, pan?:number, startTime?:number, duration?:number) : string;
	}
	
	export class TestGeneric<MyT>
	{
		protected myFunc(obj:MyT) : void;
	}
	
	export class TestGeneric extends pack_a.TestGeneric.TestBaseGeneric<root_pack.pack_a.TestClassC>
	{
	
	}
	
	export class TestProperty
	{
		get_myProp() : any
	 	set_myProp(v:any) : any;
		protected get_myProp() : any;
		protected set_myProp(v:any) : any;
	}
}

export class RootClass
{
	constructor();
}