
# Ragdoll Puppeteer

https://github.com/user-attachments/assets/0c9c8957-0ffa-4592-a3ca-d7ae0c6c2880

The [Ragdoll Puppeteer](https://steamcommunity.com/sharedfiles/filedetails/?id=3333911060) is a companion tool for prop or ragdoll animations. Unlike the Stand Poser, this tool can set any pose for the prop/ragdoll. Unlike the existing Animated Props tool, the Ragdoll Puppeteer can import custom animations from Stop Motion Helper, but it lacks some features like sequence layers. Like Ragdoll Mover (RGM) and Stop Motion Helper (SMH), the puppeteer serves as an additional utility to the GMod animator's toolkit to accelerate any animating workflow.

Here are two ways on how you can use this tool:

- "Bake" a sequence onto SMH (in whatever resolution you desire), and use the ragdoll mover and other posing tools for a new animation. For example, you can either use a premade running animation, or animate your own using SMH. With the animation, use SMH to outline a base trajectory for the ragdoll and use RGM to make adjustments to the pose on each frame.
    - If the sequence of SMH animation moves the character root, you can automate the movement of a character in Stop Motion Helper, without using RGM. For instance, one can combine this tool's update position and frame advancement commands to move the origin forward in its walk cycle.
- Initially puppeteer a prop/ragdoll to an animation frame, and then make additional adjustments using the RGM. For instance, you can first set the Heavy to his primary weapon sequence, and then adjust his hands to hold a different weapon. You can also use a pose saved from a SMH animation.

## Disclaimer

This tool has no competing conflicts of interest with Animated Props and similar tools in mind. I developed this tool with partial inspiration by the ragdollize feature in Animated Props and the Stand Poser. I hope that I inspire another improved version of this tool in Animated Props or some other tool.

**You should use this tool in singleplayer.** Many of the features here were tested in singleplayer. If your workflow requires that you animate with another animator in a server, you can use this tool in singleplayer initially and then transfer the data over to the server (assuming that you use an animation tool like SMH).

In addition, the ragdoll puppet may not exactly match the pose of the puppeteer. This is dependent on the ragdoll itself. Consider using a ragdoll with as many physical bones to animate (make collar/shoulder physical bones, increase spine count, and so on).

## Pull Requests

When making a pull request, make sure to confine to the style as that seen in ragdollpuppeteer.lua. I used the default [StyLua](https://github.com/JohnnyMorganz/StyLua) formatting style.

## Acknowledgements and Credits

- Winded and PenolAkushari: [Stand Poser](https://steamcommunity.com/sharedfiles/filedetails/?id=104576786) ([repo](https://github.com/Winded/StandingPoseTool/tree/master)) for inspiration on base implementation, [Ragdoll Mover](https://steamcommunity.com/sharedfiles/filedetails/?id=104575630) ([repo](https://github.com/Winded/RagdollMover/tree/master)) and [Stop Motion Helper](https://steamcommunity.com/sharedfiles/filedetails/?id=111895870) ([repo](https://github.com/Winded/StopMotionHelper)) for loading and handling SMH data
- no loafing: [Animated Props](https://steamcommunity.com/sharedfiles/filedetails/?id=3214437941) ([repo](https://github.com/NO-LOAFING/AnimpropOverhaul/tree/main)) for inspiration and a quick peek at the source code for hints on manipulating entity sequences and retargeting animations
- W L K R E: GLua Quaternions ([repo](https://github.com/JWalkerMailly/glua-quaternion)) for library to help work around gimbal locks related to Gestures and ManipulatedBone methods
