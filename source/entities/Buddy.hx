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

	var pathTarget:FlxObject = null;
	var resourceTimer:FlxTimer = null;
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

			pathTarget = target;
			this.path = new FlxPath(points);
			path.start(points, 200);
		}

		if (path != null)
		{
			if (path.finished)
			{
				ctx.set('resource', currentTarget);
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
		// tree to find a target object
		var getTarget = new Selector(IN_ORDER, [
			new Condition("hasTarget", VAR_SET('target')),
			new StatusAction("setClosestTarget", BT.wrapFn((ctx, delta) ->
			{
				var desire:ResType = cast ctx.get('desire');
				var objs = PlayState.ME.findObjects(desire);

				if (objs.length == 0) {
					// no resource to target
					return FAIL;
				}

				// find closest
				var minPathLength = Math.POSITIVE_INFINITY;
				var target:Resource = null;
				var points:Array<FlxPoint> = null;
				for (resource in objs) {
					var pathPoints = PlayState.ME.pathBetween(this, resource);
					var len = 0.0;
					var lastPoint:FlxPoint = null;
					for (p in pathPoints) {
						if (lastPoint == null) {
							lastPoint = p;
							continue;
						}

						len += p.distanceTo(lastPoint);
						lastPoint = p;
					}

					if (len < minPathLength) {
						minPathLength = len;
						points = pathPoints;
						target = resource;
					}
				}

				if (minPathLength != Math.POSITIVE_INFINITY) {
					ctx.set('target', target);

					// this isn't strictly necessary, but since we already computed it, set it aside for later
					ctx.set('targetPath', points);
					return SUCCESS;
				}

				// no resource is reachable
				return FAIL;
			})),
		]);

		Registry.register('findATarget', getTarget);

		// tree to get close to target object
		var approachTarget = new Selector(IN_ORDER, [
			new Condition("nearTarget", FUNC(BT.wrapFn((ctx) -> {
				var target:Resource = ctx.get('target');
				if (target.overlaps(this)) {
					ctx.set('resource', target);
					return true;
				}
				// if (target != null && getPosition().dist(target.getPosition()) < 32) {
				// 	ctx.set('resource', target);
				// 	return true;
				// };
				return false;
			}))),
			new StatusAction(BT.wrapFn(moveToTarget), BT.wrapFn((ctx) -> path.cancel()))
		]);

		Registry.register('approachTarget', approachTarget);

		// tree to interact with desire
		var interactWithTarget = new Success();

		Registry.register('interactWithTarget', approachTarget);

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

		var consumeResource = new Sequence(IN_ORDER, [
			new Subtree('findATarget'),
			new Subtree('approachTarget'),
			new StatusAction('consume', BT.wrapFn((ctx, delta) -> {
				var res:Resource = ctx.get('resource');
				if (res == null)
				{
					// no target to interact with, or it was removed
					// TODO: This does not gracefully handle if the target is removed
					// abruptly. How to address this?
					interacting = false;
					return FAIL;
				}

				if (!interacting) {
					// start interaction
					interacting = true;
					res.kill();
					if (resourceTimer != null) {
						resourceTimer.cancel();
					}
					resourceTimer = FlxTimer.loop(.5, (loop) -> {
						trace('timerLoops: ${loop}');
						if (!interacting) {
							resourceTimer.cancel();
							return;
						}

						switch (res.type) {
							case ResType.WATER:
								water += 10;
							case ResType.FOOD:
								food += 12;
						}
						if (loop == 5) {
							interacting = false;
						}
					}, 5);
				}

				if (interacting) {
					return RUNNING;
				}

				ctx.remove('desire');
				ctx.remove('target');
				ctx.remove('resource');
				return SUCCESS;
			}), BT.wrapFn((ctx) -> {
				interacting = false;
				ctx.remove('desire');
				ctx.remove('target');
				ctx.remove('resource');
				if (resourceTimer != null) {
					resourceTimer.cancel();
				}
			}))
		]);

		Registry.register('consumeResource', consumeResource);

		bt = new BTExecutor(new Repeater(FOREVER, new Sequence(IN_ORDER, [
			new Selector(IN_ORDER, [
				new Condition("notThirsty", VAR_CMP(WATER, GT(50))),
				new Sequence(IN_ORDER, [
					new SetVariable('desire', CONST(ResType.WATER)),
					new HierarchicalContext(new Subtree('consumeResource'))
				])
			]),
			new Selector(IN_ORDER, [
				new Condition("notHungry", VAR_CMP(FOOD, GT(50))),
				new Sequence(IN_ORDER, [
					new SetVariable('desire', CONST(ResType.FOOD)),
					new HierarchicalContext(new Subtree('consumeResource'))
				])
			]),
			new Selector(IN_ORDER, [
				new Condition("atMouse", FUNC(BT.wrapFn((ctx) -> {
					return getPosition().dist(FlxG.mouse.getWorldPosition()) < 32;
				}))),
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
					}), BT.wrapFn((ctx) -> {velocity.set();}))
			]),
		])));
		bt.init(ctx);
		#if debug
		DebugSuite.ME.getTool(BTreeInspector).addTree('buddy', bt);
		#end
		// @formatter:on
	}
}
