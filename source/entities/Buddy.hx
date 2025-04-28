package entities;

import bitdecay.behavior.tree.BT;
import bitdecay.behavior.tree.BTExecutor;
import bitdecay.behavior.tree.NodeStatus;
import bitdecay.behavior.tree.Registry;
import bitdecay.behavior.tree.composite.Selector;
import bitdecay.behavior.tree.composite.Sequence;
import bitdecay.behavior.tree.context.BTContext;
import bitdecay.behavior.tree.decorator.Inverter;
import bitdecay.behavior.tree.decorator.Repeater;
import bitdecay.behavior.tree.decorator.Subtree;
import bitdecay.behavior.tree.decorator.Succeeder;
import bitdecay.behavior.tree.decorator.TimeLimit;
import bitdecay.behavior.tree.leaf.Action;
import bitdecay.behavior.tree.leaf.IsVarNull;
import bitdecay.behavior.tree.leaf.RemoveVariable;
import bitdecay.behavior.tree.leaf.SetVariable;
import bitdecay.behavior.tree.leaf.StatusAction;
import bitdecay.behavior.tree.leaf.Success;
import bitdecay.behavior.tree.leaf.Wait;
import bitdecay.flixel.debug.DebugSuite;
import bitdecay.flixel.debug.tools.btree.BTreeInspector;
import bitdecay.flixel.debug.tools.btree.BTreeVisualizer;
import entities.Resource.ResType;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxVelocity;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class Buddy extends FlxSprite
{
	static inline var FOOD = 'food';
	static inline var WATER = 'water';

	public var food:Float = 70;
	public var water:Float = 70;

	var foodDrainRate:Float = 2.5;
	var waterDrainRate:Float = 5;

	var bt:BTExecutor;
	var ctx:BTContext;

	public function new(X:Float, Y:Float)
	{
		super(X, Y);
		makeGraphic(32, 32, FlxColor.YELLOW);
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

	function isThirsty(ctx:BTContext, delta:Float):NodeStatus
	{
		if (ctx.get(WATER) < 50)
		{
			return SUCCESS;
		}
		return FAIL;
	}

	function initBehavior()
	{
		var findTree = new Sequence(IN_ORDER, [
			new Inverter(new IsVarNull('desire')),
			new Action("setObjectsFromDesire", BT.wrapFn((ctx) ->
			{
				var desire:ResType = cast ctx.get('desire');
				ctx.set('objects', PlayState.ME.findObjects(desire));
			})),
			new Repeater(UNTIL_SUCCESS(0), new Sequence(IN_ORDER, [
				new StatusAction("popStack", BT.wrapFn((ctx, _) ->
				{
					var objects:Array<Resource> = cast ctx.get('objects');
					if (objects.length > 0)
					{
						ctx.set('target', objects[0]);
						objects.splice(0, 1);
						return SUCCESS;
					}

					// if we ran out of objects, remove it from the context
					ctx.remove('objects');
					return FAIL;
				})),
				new StatusAction("moveToTarget", BT.wrapFn((ctx, _) ->
				{
					var target:FlxSprite = cast ctx.get('target');
					FlxVelocity.moveTowardsObject(this, target, 200);

					if (this.overlaps(target))
					{
						ctx.remove('target');
						return SUCCESS;
					}
					else
					{
						return RUNNING;
					}
				})),
				new RemoveVariable('desire')
			]))
		]);

		Registry.register('findDesiredObject', findTree);

		bt = new BTExecutor(new Repeater(FOREVER, new Selector(IN_ORDER, [
			new Sequence(IN_ORDER, [
				new IsVarNull('desire'),
				new StatusAction("checkWater", BT.wrapFn(isThirsty)),
				new SetVariable('desire', ResType.WATER)
			]),
			new Sequence(IN_ORDER, [
				new IsVarNull('desire'),
				new StatusAction("checkFood", BT.wrapFn((ctx, delta) ->
				{
					if (ctx.get(FOOD) < 50)
					{
						return SUCCESS;
					}
					return FAIL;
				})),
				new SetVariable('desire', ResType.FOOD)
			]),
			new Selector(IN_ORDER, [
				new Sequence(IN_ORDER, [new Inverter(new IsVarNull('desire')), new Subtree('findDesiredObject')]),
				new Inverter(new TimeLimit(CONST(1.5), new StatusAction("chaseMouse", BT.wrapFn((ctx, delta) ->
				{
					var mp = FlxG.mouse.getWorldPosition();
					var p = getGraphicMidpoint().subtract(mp);
					if (p.length > 32)
					{
						velocity.copyFrom(p).scale(-1).normalize().scale(200);
					}
					else
					{
						velocity.set();
					}
					mp.put();
					p.put();
					return RUNNING;
				})))),
				new Action("stopVelocity", BT.wrapFn((ctx) ->
				{
					this.velocity.set();
				}))
			]),
			new Wait(CONST(1))
		])));
		bt.init(ctx);
		DebugSuite.ME.getTool(BTreeInspector).addTree('buddy', bt);
	}
}
