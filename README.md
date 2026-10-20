# Keys of the Angel

A World of Warcraft: Forever addon for Tauren. Run long enough for **Plainsrunning** to reach full speed and your
own soundtrack kicks in.

## What it does

- The first time Plainsrunning reaches **30 stacks** in a session, the song starts and the zone music fades out.
- After that, the song follows your speed: full volume at 30 stacks, fading to silent at 27. Slow down and the zone
  music comes back; speed back up and the song fades in again, right where it left off.
- Entering combat removes Plainsrunning, so the song fades out when a fight starts.
- The song keeps looping for the rest of the session.
- It only does anything on Tauren characters.

There are no settings. To turn it off, disable the addon in the AddOns list (Esc → AddOns).

## Sound settings

- The song's loudness follows your **Music** volume slider, so at full speed it's as loud as your zone music was.
  It plays even if you've turned game music off; only a Music slider at 0 silences it.
- The song plays on the **Dialog** sound channel. While the song is faded down, NPC voice lines are quiet too.
- Alt-tabbing out of the game stops all sound, so the song starts over from the beginning when you come back. To
  keep it playing, turn on the game's sound-in-background option in the Sound settings.

> **Heads-up:** while the addon is active it moves your Music and Dialog volumes itself. If you open the Sound
> settings, the sliders may sit at odd positions and move on their own. That's expected. Your real settings come
> back when you log out or reload. If you move a slider yourself, the addon takes that as your new setting.

## Using your own song

1. Open `Interface\AddOns\KeysOfTheAngel\media`.
2. Replace `song.mp3` with your song, named `song.mp3` or `song.ogg`. Make sure **only one** song file is in the
   folder.
3. Fully restart the game (WoW only notices new files after a restart).

Updating the addon puts the original song back, so copy yours in again after each update.

## "Keys of the Angel is damaged"

This popup means the addon's files are broken. Reinstall it: use your addon manager's reinstall option, or delete
the `KeysOfTheAngel` folder from `Interface\AddOns` and install it again. Then restart the game.

## License

MIT, see [LICENSE](LICENSE). That covers the code and the song.
