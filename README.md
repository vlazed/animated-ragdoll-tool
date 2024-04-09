
# Ragdoll Poser

The ragdoll poser is a companion tool for ragdoll animations. Unlike the stand poser, this tool can set any pose for the ragdoll. Unlike the existing Animated Props tool, there are no fancy features like gestures, layer sequences, or bone remapping; this tool was made to give the animator flexibility by making the ragdoll match its sequence poses at individual frames. I developed this to accelerate my animating workflow.

Here are two ways on how you can use this tool:

- "Bake" a sequence onto Stop Motion Helper (in whatever resolution you desire), and use the ragdoll mover and other posing tools for a new animation. For example, you can use a premade running animation to outline a base trajectory of the ragdoll, and then use ragdoll mover to make adjustments to the torso or the legs.
- Initially pose a ragdoll to a frame, and then make additional adjustments using the ragdoll mover. For instance, you can first set the Heavy to his primary weapon sequence, and then adjust his hands to hold a different weapon.

## Disclaimer

This tool has no competing conflicts of interest with Animated Props. I developed this tool with partial inspiration by the ragdollize feature in Animated Props and the Stand Poser. I hope that I inspire another improved version of this tool in Animated Props or some other tool.

You should use this tool in **singleplayer**. If your workflow requires that you animate with another animator in a server, you can use this tool in singleplayer initially and then transfer the data over to the server.

## Pull Requests

When making a pull request, make sure to confine to the style as that seen in ragdollposer.lua (no redundant spaces in function parentheses). If you use Visual Studio Code, I accompanied the repo with settings.json; make sure to install the required extensions.

## Acknowledgements and Credits

- Winded and PenolAkushari: [Stand Poser](https://steamcommunity.com/sharedfiles/filedetails/?id=104576786) ([repo](https://github.com/Winded/StandingPoseTool/tree/master)) for base implementation, Ragdoll Mover, and Stop Motion Helper; their animations tools have allowed me to motivate a new animation tool
- no loafing: [Animated Props](https://steamcommunity.com/sharedfiles/filedetails/?id=3214437941); inspiration and a quick peek at the source code for hints on manipulating entity sequences 