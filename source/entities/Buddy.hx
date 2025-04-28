package entities;

import bitdecay.behavior.tree.BTExecutor;
import bitdecay.behavior.tree.BTreeMacros;
import bitdecay.behavior.tree.Registry;
import bitdecay.behavior.tree.composite.Selector;
import bitdecay.behavior.tree.composite.Sequence;
import bitdecay.behavior.tree.context.BTContext;
import bitdecay.behavior.tree.decorator.Repeater;
import bitdecay.behavior.tree.decorator.Subtree;
import bitdecay.behavior.tree.decorator.Succeeder;
import bitdecay.behavior.tree.leaf.Action;
import bitdecay.behavior.tree.leaf.SetVariable;
import bitdecay.behavior.tree.leaf.StatusAction;
import bitdecay.behavior.tree.leaf.Success;
import bitdecay.behavior.tree.leaf.Wait;
import bitdecay.flixel.debug.DebugSuite;
import bitdecay.flixel.debug.tools.btree.BTreeInspector;
import bitdecay.flixel.debug.tools.btree.BTreeVisualizer;
import entities.Resource.ResType;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;

class Buddy extends FlxSprite
{
	static inline var FOOD = 'food';
	static inline var WATER = 'water';

	var food:Float = 100;
	var water:Float = 100;

	var foodDrainRate:Float = 2.5;
	var waterDrainRate:Float = 5;

	var bt:BTExecutor;
	var ctx:BTContext;

	public function new(X:Float, Y:Float)
	{
		super(X, Y);
		makeGraphic(16, 16, FlxColor.YELLOW);
		ctx = new BTContext();
		initBehavior();

		FlxG.watch.add(this, "food", "pFood:");
		FlxG.watch.add(this, "water", "pWater:");
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		food = Math.max(0, food - foodDrainRate * elapsed);
		water = Math.max(0, water - waterDrainRate * elapsed);

		bt.ctx.set(FOOD, food);
		bt.ctx.set(WATER, water);

		bt.process(elapsed);
	}

	function initBehavior()
	{
		var findTree = new Action(BTreeMacros.wrapFn((ctx) ->
		{
			var desire = ctx.get('desire');
			if (desire == ResType.WATER)
			{
				water += 20;
			}
			else if (desire == ResType.FOOD)
			{
				food += 15;
			}
		}));
		Registry.register('findDesiredObject', findTree);

		bt = new BTExecutor(new Repeater(FOREVER, new Selector(IN_ORDER, [
			new Sequence(IN_ORDER, [
				new StatusAction(BTreeMacros.wrapFn((ctx, delta) ->
				{
					if (ctx.get(WATER) < 50)
					{
						return SUCCESS;
					}
					return FAIL;
				})),
				new SetVariable('desire', ResType.WATER),
				new Subtree('findDesiredObject')
			]),
			new Sequence(IN_ORDER, [
				new StatusAction(BTreeMacros.wrapFn((ctx, delta) ->
				{
					if (ctx.get(FOOD) < 50)
					{
						return SUCCESS;
					}
					return FAIL;
				})),
				new SetVariable('desire', ResType.FOOD),
				new Subtree('findDesiredObject')
			]),
			new Wait(CONST(1))
		])));
		bt.init(ctx);
		DebugSuite.ME.getTool(BTreeInspector).addTree('buddy', bt);
	}
}
