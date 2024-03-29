[ Taken from thoughtbot's [intro-to-dotfiles](https://thoughtbot.com/upcase/videos/intro-to-dotfiles). ]

# Dotfile Usage Philosophy

**rules of thumb** (that can be broken)

### Value Flow
Aim to reduce friction where it is degrading flow and degrading the quality of thought. If a step is not automatic but it does not improve flow to change it, then maybe leave it as clunky. If a step is challenging to automate or smoothen but it significantly affects the flow of thought, then maybe wrestle with it despite the difficulty to wrangle it.

### Avoid cluttering the home directory
Lean on on [XDG](../profile/XDG.md).

### When in doubt, avoid automation
While this may sound heretical, we actually recommend not jumping to automate and configure too quickly. All automation has a cost (maintenance, initial setup and tweaking time, etc) so be wary of automating too quickly.

### Rule of 3
You can employ a rule of 3 to determine when to automate. If you feel the same annoyance or friction 3 times in recent memory, then the time has come to automate.

### Use Time Boxed Spikes
Once something hits the magic 3 annoyance count, give yourself a short (5-10 minutes) boxed window of time to take a stab at a first solution. When you are in context feeling the friction you often are in the best place to solve something that might otherwise never be handled.

### Capture Notes
You can use [dots repo issues](https://github.com/dfarrel1/dots/issues) as a place to track bigger problems or updates you'd like to tackle. This has a number of benefits:

### Capture annoyances that would take too much time to solve.
Allow some time to pass to make sure this annoyance is truly worth fixing
Capture any work you've done thus far. Maybe you were able to get a partial solution in your 5-10 minute time box. Save off what you have so you can come back when you have more time
Allow the future, smarter you to solve this problem. You may not have the knowledge to solve a particular problem when you first encounter it, but down the road you might!

### Share Your Dotfiles
Nearly all dotfiles repos are a collection of bits borrowed or copied from others, so it only makes sense to share yours back. This is as easy as sharing them as a public repo on Github. Dotfiles are [meant for sharing](https://zachholman.com/2010/08/dotfiles-are-meant-to-be-forked/) after all.

### Don't Use Someone Else's Dotfiles
In general, dotfiles end up being extremely specific to an individual developers workflows and preferences. As such, it's probably not a great idea to grab those and run with them.

One particular case where this is not true is the [thoughtbot dotfiles](https://github.com/thoughtbot/dotfiles). These are specifically designed to provide a minimal (but highly useful and curated!) foundation which you are then expected to layer your more specific configurations and preferences on top of.

In the [installation notes](../profile/README.md#installation-mac) for this particular dotfiles repo you will see that the core dotfiles can be stripped down to three files and you can build up from there.
