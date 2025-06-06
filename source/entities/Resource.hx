package entities;

import flixel.FlxSprite;
import flixel.util.FlxColor;

class Resource extends FlxSprite
{
	public var type:ResType;

	public function new(type:ResType, X:Float, Y:Float)
	{
		super(X, Y);
		this.type = type;
		immovable = true;

		makeGraphic(16, 16, switch (type)
		{
			case WATER:
				FlxColor.BLUE.getLightened();
			case FOOD:
				FlxColor.ORANGE;
		});
	}
}

enum ResType
{
	WATER;
	FOOD;
}
