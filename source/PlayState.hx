package;

import entities.Buddy;
import entities.Resource;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;

class PlayState extends FlxState
{
	public static var ME:PlayState;

	var buddy:Buddy;
	var food:Resource;
	var water:Resource;

	public function new()
	{
		super();
		ME = this;
	}

	override public function create()
	{
		super.create();
		buddy = new Buddy(FlxG.width / 2, FlxG.height / 2);
		food = new Resource(FOOD, FlxG.width / 3, FlxG.height * .66);
		food.immovable = true;
		water = new Resource(WATER, FlxG.width * .66, FlxG.height / 3);
		water.immovable = true;

		add(buddy);
		add(food);
		add(water);
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
	}

	public function findObjects(type:ResType):Array<Resource>
	{
		switch (type)
		{
			case WATER:
				return [water];
			case FOOD:
				return [food];
		}
	}
}
