Sognetank - Tanking Suite Addon

One-button warrior tanking for OctoWoW 1.18.1

Sognetank is a lightweight tanking addon that turns your warrior's rotation into a single macro press. It is built for OctoWoW 1.18.1, where many warrior abilities can be used outside their usual stance, so it works in any stance instead of locking you into Defensive.

Press the macro and Sognetank handles targeting, threat, interrupts, fear and emergencies, so you can focus on positioning and the fight.

Features:

Two rotations: single target and AOE, each on its own command.

Singlet target prioritizing Shield Slam and Concussion Blow in all stances. 

Thunder Clap priority in the AOE rotation, with Demoralizing Shout on a random roll so it isn't spammed.

Auto interrupt: Pummel in Berserker Stance, Shield Bash in Battle and Defensive Stance, fired when your target starts casting.
Shield Block in Defensive Stance.

Auto taunt: Taunt, or Mocking Blow in Battle Stance, when your target stops attacking you.

Fear breaker: Berserker Rage fires automatically when you are feared, or just before a known fear lands. If you are in another stance, Sognetank switches to Berserker Stance, uses Berserker Rage, and switches back.

Fear spell library: ships with the common fears (Bellowing Roar, Panic, Terrifying Roar, Terrifying Screech and more), learns new ones when you get feared, and lets you add your own.

BigWigs aware: reacts to "fear" warnings when BigWigs is running.

Emergency tools: Shield Wall and Last Stand at low HP, plus Major Healthstone at 15% HP. No potions are touched, so your potion cooldown stays free.

Small chat messages when abilities fire, for example "Warrior broke fear successfully!"

Everything can be switched off. Settings are saved between sessions.

:::Installation:::

Put the folder in World of Warcraft\Interface\AddOns\ and name it Sognetank. It must contain Sognetank.toc and Sognetank.lua.
Start the game and make sure Sognetank is ticked in the AddOns list.
You should see "Sognetank: loaded" in chat when you log in.


:::Usage:::

Make two macros and spam them in combat:

/sognetank
/sogneaoe
Command	What it does
/sognetank	Single-target rotation
/sogneaoe	AOE rotation (also /sognetankaoe or /sognetank aoe)
/sognetank msg	Toggle the info text in chat
/sognetank consume	Toggle Major Healthstone use
/sognetank emergency	Toggle Last Stand and Shield Wall
/sognetank taunt	Toggle auto taunt
/sognetank fear	Toggle the Berserker Rage fear breaker
/sognetank options	Show all settings
/sognetank listfear	Show the fear spell library
/sognetank addfear <spell>	Add a fear spell
/sognetank delfear <spell>	Remove a fear spell
/sognetank debug	Show what the addon is doing
/sognetank fearstatus	Print fear debugging info
Customising

All stance rules, rage costs and HP thresholds are in the settings block at the top of Sognetank.lua. If an ability works in a different stance on your server, change the matching table there.

Notes
Made for OctoWoW 1.18.1 on the 1.12 client. It has not been tested on other servers.
Enemy cast detection reads the combat log, so it is not instant. It uses UnitCastingInfo or SuperWoW events if your client provides them.
Feel free to open an issue if a fear spell is missing. The name in the combat log is all that is needed.
Credits

Written by Sognekongen
