package;

import bitdecay.flixel.debug.tools.draw.DebugDraw;
import flixel.FlxG;
import flixel.FlxGame;
import openfl.display.Sprite;
#if debug
import bitdecay.flixel.debug.DebugSuite;
import bitdecay.flixel.debug.tools.btree.BTreeInspector;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;
#end

class Main extends Sprite
{
	public function new()
	{
		super();
		FlxG.signals.preGameStart.add(() -> {
			#if debug
			DebugSuite.init(new BTreeInspector(), new DebugDraw());
			FlxG.debugger.visible = true;
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, function(e:KeyboardEvent)
			{
				if (FlxG.debugger.visible && FlxG.game.debugger.console.visible && e.keyCode == Keyboard.SLASH)
				{
					@:privateAccess
					FlxG.stage.focus = FlxG.game.debugger.console.input;
				}
			});
			#end
		});
		addChild(new FlxGame(0, 0, PlayState, true));
	}
}
