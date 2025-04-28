package;

import entities.Buddy;
import entities.Resource;
import flixel.FlxG;
import flixel.FlxState;

class PlayState extends FlxState
{
	public static var ME:PlayState;

	var buddy:Buddy;

	public function new()
	{
		super();
		ME = this;
	}

	override public function create()
	{
		super.create();
		buddy = new Buddy(FlxG.width / 2, FlxG.height / 2);
		var food = new Resource(FOOD, 10, FlxG.height - 32);
		var water = new Resource(WATER, FlxG.width - 30, 10);
		
		add(buddy);
		add(food);
		add(water);
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
	}
}
