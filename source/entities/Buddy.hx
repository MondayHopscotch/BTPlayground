package entities;

import bitdecay.flixel.debug.DebugSuite;
import bitdecay.flixel.debug.tools.btree.*;
import entities.Resource.ResType;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxVelocity;
import flixel.path.FlxPath;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

class Buddy extends FlxSprite
{
	static inline var FOOD = 'food';
	static inline var WATER = 'water';

	public var food:Float = 70;
	public var water:Float = 70;

	var foodDrainRate:Float = 1;
	var waterDrainRate:Float = 1.5;

	var interacting = false;

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
		FlxG.watch.add(this, "velocity", "velocity");
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

	override function draw()
	{
		super.draw();
		if (path != null)
		{
			path.drawDebugOnCamera(camera);
		}
	}

	function isThirsty(ctx:BTContext, delta:Float):NodeStatus
	{
		if (ctx.get(WATER) < 50)
		{
			return SUCCESS;
		}
		return FAIL;
	}

	function startInteraction(ctx:BTContext)
	{
		var res:Resource = ctx.get('resource');
		if (res == null)
		{
			interacting = false;
			return;
		}

		interacting = true;
		// simulate interaction while we have no animations
		FlxTimer.wait(1, () ->
		{
			switch (res.type)
			{
				case ResType.WATER:
					water += 40;
				case ResType.FOOD:
					food += 50;
			}
			interacting = false;
		});
	}

	public function touched(r:FlxObject)
	{
		if (currentTarget == r)
		{
			bt.ctx.set('resource', r);

			if (path != null)
			{
				path.cancel();
				path = null;
				pathSuccess = true;
			}
		}
	}

	var currentTarget:FlxObject;
	var pathSuccess = false;

	function moveToTarget(ctx:BTContext, delta:Float):NodeStatus
	{
		var target:FlxSprite = cast ctx.get('target');
		if (target == null)
		{
			if (path != null && !path.finished)
			{
				path.cancel();
			}
			return FAIL;
		}
		else if (currentTarget != target)
		{
			if (path != null && !path.finished)
			{
				path.cancel();
			}

			currentTarget = target;
			var points = PlayState.ME.pathBetween(this, target);
			if (points == null)
			{
				// can't get there
				return FAIL;
			}

			this.path = new FlxPath(points);
			path.start(points, 200);
		}

		if (path != null)
		{
			if (path.finished)
			{
				currentTarget = null;
				ctx.remove('target');
				return SUCCESS;
			}

			return RUNNING;
		}

		if (path == null && pathSuccess)
		{
			currentTarget = null;
			ctx.remove('target');
			return SUCCESS;
		}

		return FAIL;
	}

	function initBehavior()
	{
		// @formatter:off
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
				new StatusAction("moveToTarget", BT.wrapFn(moveToTarget)),
				new RemoveVariable('desire')
			]))
		]);

		Registry.register('findDesiredObject', findTree);

		bt = new BTExecutor(new Repeater(FOREVER, new Selector(IN_ORDER, [
			new Sequence(IN_ORDER, [
				new IsVarNull('desire'),
				new Condition("checkThirsty", VAR_CMP(WATER, LT(50))),
				new SetVariable('desire', CONST(ResType.WATER))
			]),
			new Sequence(IN_ORDER, [
				new IsVarNull('desire'),
				new Condition("checkHungry", VAR_CMP(FOOD, LT(50))),
				new SetVariable('desire', CONST(ResType.FOOD))
			]),
			new Selector(IN_ORDER, [
				new Sequence(IN_ORDER, [
					new Inverter(new IsVarNull('desire')),
					new Subtree('findDesiredObject'),
					new Inverter(new IsVarNull('resource')),
					new Action(BT.wrapFn(startInteraction)),
					new StatusAction('waitForInteractionFinish', BT.wrapFn((ctx, delta) -> {
						if (interacting) {
							return RUNNING;
						}

						ctx.remove('resource');
						return SUCCESS;
					}))
				]),
				new Inverter(
					new TimeLimit(CONST(1.5),
					new StatusAction("chaseMouse", BT.wrapFn((ctx, delta) -> {
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
		#if debug
		DebugSuite.ME.getTool(BTreeInspector).addTree('buddy', bt);
		#end
		// @formatter:on
	}
}
