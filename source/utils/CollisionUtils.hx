package utils;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxG;

class CollisionUtils
{
	public static function piecewiseCollide(?objectOrGroup1:FlxBasic, ?objectOrGroup2:FlxBasic, ?notifyCallback:Dynamic->Dynamic->Void):Bool
	{
		return FlxG.overlap(objectOrGroup1, objectOrGroup2, notifyCallback, piecewiseSeparate);
	}

	/**
	 * Separates 2 overlapping objects. If an object is a tilemap,
	 * it will separate it from any tiles that overlap it.
	 * 
	 * @return  Whether the objects were overlapping and were separated
	 */
	public static function piecewiseSeparate(object1:FlxObject, object2:FlxObject):Bool
	{
		var tmp1 = object1.last.copyTo();
		var tmp2 = object2.last.copyTo();
		final separatedX = FlxObject.separateX(object1, object2);
		object1.last.x = object1.x;
		object2.last.x = object2.x;
		final separatedY = FlxObject.separateY(object1, object2);
		object1.last.copyFrom(tmp1);
		object2.last.copyFrom(tmp2);
		tmp1.put();
		tmp2.put();
		return separatedX || separatedY;
	}
}