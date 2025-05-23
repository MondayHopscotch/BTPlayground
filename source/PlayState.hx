package;

import entities.Buddy;
import entities.Resource;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.editors.ogmo.FlxOgmo3Loader;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.tile.FlxTilemap;
import utils.CollisionUtils;

class PlayState extends FlxState
{
	public static var ME:PlayState;

	var tilemap:FlxTilemap;
	var buddy:Buddy;

	var resources = new FlxTypedGroup<Resource>();

	public function new()
	{
		super();
		ME = this;
	}

	override public function create()
	{
		var loader = new FlxOgmo3Loader(AssetPaths.world__ogmo, AssetPaths.first__json);
		tilemap = loader.loadTilemap(AssetPaths.tiles__png, "walls");

		super.create();
		buddy = new Buddy(FlxG.width / 2, FlxG.height / 2);
		var food = new Resource(FOOD, 16 * 10, 16 * 30);
		food.immovable = true;
		resources.add(food);

		var water = new Resource(WATER, 32, 32);
		water.immovable = true;
		resources.add(water);

		water = new Resource(WATER, 16 * 20, 16 * 20);
		water.immovable = true;
		resources.add(water);

		add(tilemap);
		add(buddy);
		add(resources);
	}

	public function pathBetween(a:FlxObject, b:FlxObject):Array<FlxPoint>
	{
		var path = tilemap.findPath(a.getMidpoint(), b.getMidpoint());
		return path;
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.mouse.justPressed)
		{
			var deleted = false;
			for (r in resources)
			{
				if (r.overlapsPoint(FlxG.mouse.getWorldPosition()))
				{
					r.kill();
					deleted = true;
					break;
				}
			}

			if (!deleted)
			{
				var water = new Resource(WATER, FlxG.mouse.x, FlxG.mouse.y);
				resources.add(water);
			}
		}

		if (FlxG.mouse.justPressedRight)
		{
			var deleted = false;
			for (r in resources)
			{
				if (r.overlapsPoint(FlxG.mouse.getWorldPosition()))
				{
					r.kill();
					deleted = true;
					break;
				}
			}

			if (!deleted)
			{
				var food = new Resource(FOOD, FlxG.mouse.x, FlxG.mouse.y);
				resources.add(food);
			}
		}

		CollisionUtils.piecewiseCollide(tilemap, buddy);
		CollisionUtils.piecewiseCollide(buddy, resources, (b, r) ->
		{
			buddy.touched(r);
		});
	}

	public function findObjects(type:ResType):Array<Resource>
	{
		var found:Array<Resource> = [];
		for (r in resources)
		{
			if (r.alive && r.type == type)
			{
				found.push(r);
			}
		}

		return found;
	}
}
